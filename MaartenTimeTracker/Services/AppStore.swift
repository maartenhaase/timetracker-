import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppStore: ObservableObject {
    @Published var clients:[Client]=[]
    @Published var projects:[WorkProject]=[]
    @Published var dailyTasks:[DailyTask]=[]
    @Published var workBlocks:[WorkBlock]=[]
    @Published var activeBlock:ActiveWorkBlock?
    @Published var parkedItems:[ParkedWorkItem]=[]
    @Published var activeDistraction:ActiveDistraction?
    @Published var distractionPeriods:[DistractionPeriod]=[]
    @Published var balanceDays:[BalanceDay]=[]
    @Published var closedWorkdays:[ClosedWorkday]=[]
    @Published var companyItems:[CompanyWorkItem]=[]
    @Published var manualBillingEntries:[ManualBillingEntry]=[]
    @Published var medicationEntries:[MedicationEntry]=[]
    @Published var coffeeEntries:[CoffeeEntry]=[]
    @Published var wellbeingEntries:[WellbeingEntry]=[]
    @Published var sleepEntries:[SleepEntry]=[]
    @Published var lastRewardMessage:String?

    init(){
        let state=PersistenceController.shared.load()
        clients=state.clients; projects=state.projects; dailyTasks=state.dailyTasks; workBlocks=state.workBlocks
        activeBlock=state.activeBlock; parkedItems=state.parkedItems; activeDistraction=state.activeDistraction
        distractionPeriods=state.distractionPeriods; balanceDays=state.balanceDays; closedWorkdays=state.closedWorkdays
        companyItems=state.companyItems; manualBillingEntries=state.manualBillingEntries
        medicationEntries=state.medicationEntries; coffeeEntries=state.coffeeEntries
        wellbeingEntries=state.wellbeingEntries; sleepEntries=state.sleepEntries
        migrateLegacyData()
        safelyParkOvernightBlock()
        seedCompanyExamplesIfEmpty()
        save()
    }

    var isDistracted:Bool{activeDistraction != nil}
    var isTodayClosed:Bool{closedWorkdays.contains{Calendar.current.isDateInToday($0.date)}}
    var activeProject:WorkProject?{ guard let id=activeBlock?.projectID else{return nil}; return projects.first{$0.id==id} }
    var activeClient:Client?{ guard let id=activeBlock?.clientID else{return nil}; return clients.first{$0.id==id} }

    var todayTasks:[DailyTask]{dailyTasks.filter{Calendar.current.isDateInToday($0.date)}}
    var openTodayTasks:[DailyTask]{todayTasks.filter{!$0.isDone}}
    var doneTodayTasks:[DailyTask]{todayTasks.filter{$0.isDone}.sorted{($0.completedAt ?? $0.date) > ($1.completedAt ?? $1.date)}}
    var quickTasksToday:[DailyTask]{openTodayTasks.filter{$0.kind == .quick || $0.plannedMinutes <= 5}}
    var deadlineTaskToday:DailyTask?{openTodayTasks.first{$0.kind == .deadline}}
    var companyTasksToday:[DailyTask]{openTodayTasks.filter{$0.kind == .company}}
    var normalTasksToday:[DailyTask]{openTodayTasks.filter{$0.kind == .normal && $0.plannedMinutes > 5}}
    var quickBundleMinutes:Int{ min(20,max(5,quickTasksToday.count*5)) }

    var startableTodayTasks:[DailyTask]{
        let parkedIDs=Set(parkedItems.compactMap(\.dailyTaskID))
        return openTodayTasks.filter{!parkedIDs.contains($0.id)}
    }

    var suggestedCompanyItem:CompanyWorkItem?{
        let active=companyItems.filter{!$0.isArchived}
        return active.sorted{
            switch($0.lastWorkedAt,$1.lastWorkedAt){
            case(nil,nil): return $0.title < $1.title
            case(nil,_): return true
            case(_,nil): return false
            case(let l?,let r?): return l<r
            }
        }.first
    }

    var suggestedCRMProjects:[WorkProject]{
        let active=projects.filter{!$0.isArchived}
        return active.sorted{suggestionScore($0)>suggestionScore($1)}.prefix(5).map{$0}
    }

    var todayDistractions:[DistractionPeriod]{distractionPeriods.filter{Calendar.current.isDateInToday($0.startedAt)}}
    var currentDistractionSeconds:TimeInterval{
        guard let d=activeDistraction else{return 0}
        return max(0,Date().timeIntervalSince(d.startedAt))
    }
    var distractionSecondsToday:TimeInterval{todayDistractions.reduce(0){$0+$1.duration}+currentDistractionSeconds}
    var recoverySecondsToday:TimeInterval{
        workBlocks.filter{Calendar.current.isDateInToday($0.startedAt)&&$0.isRecovery}.reduce(0){$0+$1.focusedSeconds}
    }
    var recoveryOpenSeconds:TimeInterval{max(0,distractionSecondsToday-recoverySecondsToday)}
    var recoverySuggestionMinutes:Int{
        guard recoveryOpenSeconds>=5*60 else{return 0}
        return recoveryOpenSeconds<=15*60 ? 15:30
    }

    var focusMessage:String{
        let wins=workBlocks.filter{Calendar.current.isDateInToday($0.startedAt)&&isStrongFocus($0)}.count
        if wins==0{return "Eén goed blok is vandaag al winst."}
        if wins==1{return "Je hebt vandaag al een sterk focusblok neergezet."}
        return "Je hebt vandaag meerdere sterke focusblokken neergezet."
    }

    // MARK: - Clients / projects / CRM

    func addClient(_ name:String,kind:ClientKind){
        let n=clean(name); guard !n.isEmpty else{return}
        clients.append(Client(name:n,kind:kind)); save()
    }

    func setClientKind(_ client:Client,kind:ClientKind){
        guard let i=clients.firstIndex(where:{$0.id==client.id}) else{return}
        clients[i].kind=kind
        for p in projects.indices where projects[p].clientID==client.id {
            projects[p].kind = kind == .wedding ? .wedding:.business
            ensureProjectTasks(index:p)
        }
        save()
    }

    func archiveClient(_ client:Client){
        guard let i=clients.firstIndex(where:{$0.id==client.id}) else{return}
        clients[i].isArchived=true
        for p in projects.indices where projects[p].clientID==client.id { projects[p].isArchived=true }
        save()
    }

    func restoreClient(_ client:Client){
        guard let i=clients.firstIndex(where:{$0.id==client.id}) else{return}
        clients[i].isArchived=false; save()
    }

    func deleteClient(_ client:Client){
        let ids=Set(projects.filter{$0.clientID==client.id}.map(\.id))
        guard activeBlock?.clientID != client.id,
              !parkedItems.contains(where:{$0.clientID==client.id}) else{return}
        clients.removeAll{$0.id==client.id}; projects.removeAll{$0.clientID==client.id}
        dailyTasks.removeAll{if let id=$0.projectID{return ids.contains(id)};return false}
        save()
    }

    func addWeddingInquiry(names:String,weddingDate:Date?,email:String="",phone:String=""){
        let n=clean(names); guard !n.isEmpty else{return}
        let client=Client(name:n,kind:.wedding,email:clean(email),phone:clean(phone))
        clients.append(client)
        projects.append(WorkProject(clientID: client.id, name: "Trouwfilm", kind: .wedding, deadline: weddingDate, weddingDate: weddingDate, weddingStepIndex: 1))
        save()
    }

    func addBusinessProject(clientID:UUID,name:String,deadline:Date?=nil){
        let n=clean(name); guard !n.isEmpty else{return}
        projects.append(WorkProject(clientID:clientID,name:n,kind:.business,deadline:deadline))
        save()
    }

    func addProject(clientID:UUID,name:String){
        guard let client=clients.first(where:{$0.id==clientID}) else{return}
        let kind:ProjectKind=client.kind == .wedding ? .wedding:.business
        projects.append(WorkProject(clientID:clientID,name:clean(name),kind:kind))
        save()
    }

    func archiveProject(_ project:WorkProject){
        guard let i=projects.firstIndex(where:{$0.id==project.id}) else{return}
        projects[i].isArchived=true; save()
    }

    func restoreProject(_ project:WorkProject){
        guard let i=projects.firstIndex(where:{$0.id==project.id}) else{return}
        projects[i].isArchived=false; save()
    }

    func deleteProject(_ project:WorkProject){
        guard activeBlock?.projectID != project.id,!parkedItems.contains(where:{$0.projectID==project.id}) else{return}
        projects.removeAll{$0.id==project.id}; dailyTasks.removeAll{$0.projectID==project.id}; save()
    }

    func addCustomTask(projectID:UUID,name:String){
        let n=clean(name); guard !n.isEmpty,let i=projects.firstIndex(where:{$0.id==projectID}) else{return}
        if !projects[i].taskNames.contains(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) { projects[i].taskNames.append(n); save() }
    }

    func nextCRMStage(for project:WorkProject)->String{
        if project.kind == .wedding {
            let i=min(max(0,project.weddingStepIndex),weddingCRMStages.count-1)
            return weddingCRMStages[i]
        } else {
            let i=min(max(0,project.businessStepIndex),businessCRMStages.count-1)
            return businessCRMStages[i]
        }
    }

    func completedCRMStages(for project:WorkProject)->[String]{
        if project.kind == .wedding { return Array(weddingCRMStages.prefix(max(0,project.weddingStepIndex))) }
        return Array(businessCRMStages.prefix(max(0,project.businessStepIndex)))
    }

    func advanceCRM(_ project:WorkProject){
        guard let i=projects.firstIndex(where:{$0.id==project.id}) else{return}
        if projects[i].kind == .wedding { projects[i].weddingStepIndex=min(weddingCRMStages.count-1,projects[i].weddingStepIndex+1) }
        else { projects[i].businessStepIndex=min(businessCRMStages.count-1,projects[i].businessStepIndex+1) }
        save()
    }

    func retreatCRM(_ project:WorkProject){
        guard let i=projects.firstIndex(where:{$0.id==project.id}) else{return}
        if projects[i].kind == .wedding { projects[i].weddingStepIndex=max(0,projects[i].weddingStepIndex-1) }
        else { projects[i].businessStepIndex=max(0,projects[i].businessStepIndex-1) }
        save()
    }

    func setProjectDate(_ project:WorkProject,date:Date?){
        guard let i=projects.firstIndex(where:{$0.id==project.id}) else{return}
        if projects[i].kind == .wedding { projects[i].weddingDate=date }
        projects[i].deadline=date; save()
    }

    func planNextCRMStage(_ project:WorkProject){
        let step=nextCRMStage(for:project)
        let quick=isQuickCRMStage(step)
        let minutes=quick ? 5 : suggestedMinutesForCRM(step)
        _=addDailyTask(projectID:project.id,category:categoryForCRM(step),title:step,plannedMinutes:minutes,kind:quick ? .quick:.normal,deadline:project.deadline)
    }


    func planSuggestedDeadline(_ project: WorkProject) {
        let step = nextCRMStage(for: project)
        let minutes: Int
        let category: String
        if project.kind == .wedding && step.lowercased().contains("ruwe montage") {
            minutes = 120; category = "Ruwe montage"
        } else if project.kind == .wedding && step.lowercased().contains("fijne montage") {
            minutes = 120; category = "Fijne montage"
        } else {
            minutes = max(60, suggestedMinutesForCRM(step)); category = categoryForCRM(step)
        }
        _ = addDailyTask(projectID: project.id, category: category, title: step, plannedMinutes: minutes, kind: .deadline, deadline: project.deadline)
    }

    func addBusinessRevision(_ project: WorkProject) {
        guard let i = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[i].businessRevisionCount += 1
        let count = projects[i].businessRevisionCount
        _ = addDailyTask(projectID: project.id, category: "Aanpassingsronde", title: "Aanpassingsronde \(count)", plannedMinutes: 30, kind: .normal)
        save()
    }

    func addBusinessExtra(_ project: WorkProject, title: String) {
        let t = clean(title)
        guard !t.isEmpty else { return }
        _ = addDailyTask(projectID: project.id, category: "Meerwerk / extra / upsell", title: t, plannedMinutes: 30, kind: .normal)
    }

    // MARK: - Wedding edit budgets

    func weddingBudgetMinutes(category:String)->Int?{
        let c=category.lowercased()
        if c.contains("ruwe montage"){return 120}
        if c.contains("fijne montage"){return 480}
        if c.contains("eindmontage") || c.contains("afronden"){return 120}
        if c.contains("aanpass"){return 60}
        return nil
    }

    func focusedMinutes(projectID:UUID,category:String)->Int{
        Int(workBlocks.filter{$0.projectID==projectID && normalizedPhase($0.category)==normalizedPhase(category)}
            .reduce(0){$0+$1.focusedSeconds}/60)
    }

    func weddingTotalEditMinutes(projectID:UUID)->Int{
        let phases=["Ruwe montage","Fijne montage","Eindmontage / afronden"]
        return phases.reduce(0){$0+focusedMinutes(projectID:projectID,category:$1)}
    }

    func weddingBudgetMessage(projectID:UUID,category:String)->String?{
        guard let budget=weddingBudgetMinutes(category:category) else{return nil}
        let used=focusedMinutes(projectID:projectID,category:category)
        if used>=budget {
            if normalizedPhase(category)=="ruwe"{return "Budget ruwe montage bereikt. Dit hoeft nog niet mooi te zijn; ga liefst door naar fijne montage."}
            if normalizedPhase(category)=="fijn"{return "Budget fijne montage bereikt. Tijd om naar eindmontage / afronden te gaan."}
            if normalizedPhase(category)=="eind"{return "Afrondbudget bereikt. Controleer en lever op; vermijd nu grote creatieve verbouwingen."}
            return "Standaard aanpassingsbuffer bereikt. Controleer of extra tijd meerwerk is."
        }
        if used >= Int(Double(budget)*0.75){return "Je zit op ongeveer 75% van het budget voor deze fase (\(durationTextLocal(used)) van \(durationTextLocal(budget)))."}
        return nil
    }

    // MARK: - Day planning

    @discardableResult
    func addDailyTask(projectID: UUID?, category: String, title: String, plannedMinutes: Int, kind: DailyTaskKind = .normal, deadline: Date? = nil) -> DailyTask? {
        let cat=clean(category); let t=clean(title); let effective=t.isEmpty ? (cat.isEmpty ? "Werk":cat):t
        guard !effective.isEmpty else{return nil}
        var finalKind=kind
        if plannedMinutes<=5 && kind == .normal { finalKind = .quick }
        if finalKind == .deadline { clearOtherDeadlineTasks() }
        let task=DailyTask(projectID:projectID,title:effective,category:cat.isEmpty ? "Werk":cat,date:Calendar.current.startOfDay(for:Date()),plannedMinutes:plannedMinutes,isDone:false,kind:finalKind,deadline:deadline)
        dailyTasks.append(task); reopenWorkdayIfNeeded(); save(); return task
    }

    func addQuickTask(title:String,projectID:UUID?=nil){
        _=addDailyTask(projectID:projectID,category:"Snelle taak",title:title,plannedMinutes:5,kind:.quick)
    }

    func makeDeadlineTask(_ task:DailyTask){
        clearOtherDeadlineTasks()
        guard let i=dailyTasks.firstIndex(where:{$0.id==task.id}) else{return}
        dailyTasks[i].kind = .deadline
        if dailyTasks[i].plannedMinutes<45 {dailyTasks[i].plannedMinutes=60}
        save()
    }

    func planCompanyItem(_ item:CompanyWorkItem){
        let title=clean(item.nextStep).isEmpty ? item.title:"\(item.title) — \(item.nextStep)"
        _=addDailyTask(projectID:nil,category:"Aan mijn bedrijf werken",title:title,plannedMinutes:item.defaultMinutes,kind:.company)
    }

    func addCompanyItem(title:String,nextStep:String="",minutes:Int=30){
        let t=clean(title);guard !t.isEmpty else{return}
        companyItems.append(CompanyWorkItem(title:t,nextStep:clean(nextStep),defaultMinutes:minutes));save()
    }

    func updateCompanyItem(_ item:CompanyWorkItem,nextStep:String){
        guard let i=companyItems.firstIndex(where:{$0.id==item.id}) else{return}
        companyItems[i].nextStep=clean(nextStep);save()
    }

    func archiveCompanyItem(_ item:CompanyWorkItem){
        guard let i=companyItems.firstIndex(where:{$0.id==item.id}) else{return}
        companyItems[i].isArchived=true;save()
    }

    func restoreCompanyItem(_ item: CompanyWorkItem) {
        guard let i = companyItems.firstIndex(where: { $0.id == item.id }) else { return }
        companyItems[i].isArchived = false
        save()
    }

    func deleteCompanyItem(_ item: CompanyWorkItem) {
        companyItems.removeAll { $0.id == item.id }
        save()
    }

    func recordDoneToday(projectID:UUID?,category:String,title:String,minutes:Int){
        let cat=clean(category);let t=clean(title);let effective=t.isEmpty ? (cat.isEmpty ? "Werk":cat):t
        guard !effective.isEmpty else{return}
        let now=Date();let task=DailyTask(projectID:projectID,title:effective,category:cat.isEmpty ? "Werk":cat,date:Calendar.current.startOfDay(for:now),plannedMinutes:minutes,isDone:true,completedAt:now,kind:minutes<=5 ? .quick:.normal)
        dailyTasks.append(task)
        if let p=projectID,let project=projects.first(where:{$0.id==p}){
            let focused=TimeInterval(minutes*60)
            workBlocks.insert(WorkBlock(clientID:project.clientID,projectID:p,dailyTaskID:task.id,billingUnitID:task.billingUnitID,category:task.category,task:task.title,plannedMinutes:minutes,startedAt:now.addingTimeInterval(-focused),endedAt:now,distractionSeconds:0,focusedSeconds:focused,billableMinutes:billableMinutes(for:focused),result:.done),at:0)
        }
        lastRewardMessage="Mooi. Dit heb je vandaag al gedaan.";playRewardSound();save()
    }

    func completeQuickTask(_ task:DailyTask){
        guard let i=dailyTasks.firstIndex(where:{$0.id==task.id}) else{return}
        dailyTasks[i].isDone=true;dailyTasks[i].completedAt=Date()
        if let p=task.projectID,let project=projects.first(where:{$0.id==p}){
            let focused:TimeInterval=5*60
            workBlocks.insert(WorkBlock(clientID:project.clientID,projectID:p,dailyTaskID:task.id,billingUnitID:task.billingUnitID,category:task.category,task:task.title,plannedMinutes:5,startedAt:Date().addingTimeInterval(-focused),endedAt:Date(),distractionSeconds:0,focusedSeconds:focused,billableMinutes:15,result:.done),at:0)
        }
        playRewardSound();save()
    }

    func startQuickBundle(){
        guard activeBlock==nil,!quickTasksToday.isEmpty else{return}
        activeBlock=ActiveWorkBlock(clientID:nil,projectID:nil,dailyTaskID:nil,billingUnitID:UUID(),category:"Snelle dingen",task:"Snelle dingen afhandelen",plannedMinutes:quickBundleMinutes)
        reopenWorkdayIfNeeded();save()
    }

    func startDailyTask(_ task:DailyTask,asRecovery:Bool=false){
        guard activeBlock==nil else{return}
        let project=task.projectID.flatMap{id in projects.first{$0.id==id}}
        activeBlock=ActiveWorkBlock(clientID:project?.clientID,projectID:task.projectID,dailyTaskID:task.id,billingUnitID:task.billingUnitID,category:task.category,task:task.title,plannedMinutes:task.plannedMinutes,isRecovery:asRecovery)
        activeDistraction=nil;lastRewardMessage=nil;reopenWorkdayIfNeeded();save()
    }

    func startDistraction(){guard activeBlock != nil,activeDistraction==nil else{return};activeDistraction=ActiveDistraction(startedAt:Date());save()}

    func endDistraction(){
        guard var block=activeBlock,let d=activeDistraction else{return}
        let now=Date();let duration=max(0,now.timeIntervalSince(d.startedAt));block.distractionSeconds+=duration;activeBlock=block
        distractionPeriods.insert(DistractionPeriod(startedAt:d.startedAt,endedAt:now,task:block.task),at:0)
        activeDistraction=nil;lastRewardMessage="Goed gezien. Je bent terug bij je blok.";save()
    }

    func finishActiveBlock(done:Bool){
        guard var block=activeBlock else{return}
        if activeDistraction != nil {endDistraction();guard let fresh=activeBlock else{return};block=fresh}
        let session=makeSession(from:block,result:done ? .done:.stopped)
        if block.category != "Snelle dingen" {workBlocks.insert(session,at:0)}
        if done,let id=block.dailyTaskID,let i=dailyTasks.firstIndex(where:{$0.id==id}){dailyTasks[i].isDone=true;dailyTasks[i].completedAt=session.endedAt}
        if done,block.category=="Aan mijn bedrijf werken"{
            if let i=companyItems.indices.first(where:{ block.task.lowercased().contains(companyItems[$0].title.lowercased()) }){companyItems[i].lastWorkedAt=Date()}
        }
        activeBlock=nil;activeDistraction=nil
        if done {lastRewardMessage="Klaar. Dit telt.";playRewardSound()}
        else if isStrongFocus(session){lastRewardMessage="Goed blok gewerkt. Het hoefde niet af om te tellen.";playRewardSound()}
        else{lastRewardMessage="Blok gestopt. De taak blijft beschikbaar."}
        save()
    }

    func parkActiveBlock(resumeNote:String){
        guard var block=activeBlock else{return}
        if activeDistraction != nil {endDistraction();guard let fresh=activeBlock else{return};block=fresh}
        let session=makeSession(from:block,result:.parked)
        if block.category != "Snelle dingen" {workBlocks.insert(session,at:0)}
        parkedItems.removeAll{$0.billingUnitID==block.billingUnitID}
        parkedItems.insert(ParkedWorkItem(clientID:block.clientID,projectID:block.projectID,dailyTaskID:block.dailyTaskID,billingUnitID:block.billingUnitID,category:block.category,task:block.task,plannedMinutes:block.plannedMinutes,resumeNote:clean(resumeNote).isEmpty ? "Ga verder waar je gebleven was.":clean(resumeNote),parkedAt:Date()),at:0)
        activeBlock=nil;activeDistraction=nil;lastRewardMessage="Veilig geparkeerd. Je hoeft dit nu niet in je hoofd te houden.";if isStrongFocus(session){playRewardSound()};save()
    }

    func resumeParked(_ item:ParkedWorkItem,asRecovery:Bool=false){
        guard activeBlock==nil else{return}
        activeBlock=ActiveWorkBlock(clientID:item.clientID,projectID:item.projectID,dailyTaskID:item.dailyTaskID,billingUnitID:item.billingUnitID,category:item.category,task:item.task,plannedMinutes:item.plannedMinutes,isRecovery:asRecovery)
        parkedItems.removeAll{$0.id==item.id};lastRewardMessage="Begin weer bij: \(item.resumeNote)";reopenWorkdayIfNeeded();save()
    }

    func removeParked(_ item:ParkedWorkItem){parkedItems.removeAll{$0.id==item.id};save()}
    func deleteDailyTask(_ task:DailyTask){guard activeBlock?.dailyTaskID != task.id,!parkedItems.contains(where:{$0.dailyTaskID==task.id}) else{return};dailyTasks.removeAll{$0.id==task.id};save()}
    func moveTaskToTomorrow(_ task:DailyTask){guard let i=dailyTasks.firstIndex(where:{$0.id==task.id}),let tomorrow=Calendar.current.date(byAdding:.day,value:1,to:Date()) else{return};dailyTasks[i].date=Calendar.current.startOfDay(for:tomorrow);dailyTasks[i].isDone=false;dailyTasks[i].completedAt=nil;save()}

    // MARK: - Billing

    var billingProjectSummaries:[BillingProjectSummary]{
        let sessions=workBlocks.filter{!$0.invoiced && $0.projectID != nil && $0.clientID != nil && $0.focusedSeconds>0}
        let unitGroups=Dictionary(grouping:sessions,by:\.billingUnitID)
        let units:[BillingUnitSummary]=unitGroups.compactMap{unitID,parts in
            guard let f=parts.first,let cid=f.clientID,let pid=f.projectID else{return nil}
            let focused=parts.reduce(0){$0+$1.focusedSeconds};guard focused>0 else{return nil}
            return BillingUnitSummary(id:unitID,clientID:cid,projectID:pid,category:f.category,task:f.task,firstDate:parts.map(\.startedAt).min() ?? f.startedAt,focusedSeconds:focused,billableMinutes:billableMinutes(for:focused))
        }
        let byProject=Dictionary(grouping:units,by:\.projectID)
        return byProject.compactMap{pid,us in guard let f=us.first else{return nil};return BillingProjectSummary(clientID:f.clientID,projectID:pid,units:us.sorted{$0.firstDate>$1.firstDate},totalBillableMinutes:us.reduce(0){$0+$1.billableMinutes})}
            .sorted{clientName(for:$0.clientID)<clientName(for:$1.clientID)}
    }

    var openManualBilling:[ManualBillingEntry]{manualBillingEntries.filter{!$0.invoiced}.sorted{$0.date>$1.date}}

    func addManualBilling(clientID:UUID,projectID:UUID?,description:String,minutes:Int,date:Date=Date()){
        let d=clean(description);guard !d.isEmpty,minutes>0 else{return}
        manualBillingEntries.append(ManualBillingEntry(clientID:clientID,projectID:projectID,date:date,description:d,minutes:minutes));save()
    }

    func markBillingUnitInvoiced(_ id:UUID){for i in workBlocks.indices where workBlocks[i].billingUnitID==id{workBlocks[i].invoiced=true};lastRewardMessage="Gefactureerd. Uit je hoofd.";playRewardSound();save()}
    func markProjectInvoiced(_ projectID:UUID){for i in workBlocks.indices where workBlocks[i].projectID==projectID{workBlocks[i].invoiced=true};for i in manualBillingEntries.indices where manualBillingEntries[i].projectID==projectID{manualBillingEntries[i].invoiced=true};lastRewardMessage="Projecttijd gefactureerd. Klaar.";playRewardSound();save()}
    func markManualBillingInvoiced(_ entry:ManualBillingEntry){guard let i=manualBillingEntries.firstIndex(where:{$0.id==entry.id}) else{return};manualBillingEntries[i].invoiced=true;save()}

    func billingExportText()->String{
        var lines=["NOG TE FACTUREREN"]
        for p in billingProjectSummaries{
            lines.append("")
            lines.append("\(clientName(for:p.clientID)) — \(projectName(for:p.projectID))")
            for u in p.units{lines.append("  \(u.task) · \(u.category) · \(durationTextLocal(u.billableMinutes))")}
            lines.append("  TOTAAL \(durationTextLocal(p.totalBillableMinutes))")
        }
        if !openManualBilling.isEmpty{
            lines.append("");lines.append("HANDMATIG")
            for e in openManualBilling{lines.append("  \(clientName(for:e.clientID)) — \(projectName(for:e.projectID)) · \(e.description) · \(durationTextLocal(e.minutes))")}
        }
        return lines.joined(separator:"\n")
    }

    func copyBillingList(){NSPasteboard.general.clearContents();NSPasteboard.general.setString(billingExportText(),forType:.string);lastRewardMessage="Facturatielijst gekopieerd."}

    // MARK: - Balance / close day

    func balanceForToday()->BalanceDay{balanceDays.first{Calendar.current.isDateInToday($0.date)} ?? BalanceDay(date:Calendar.current.startOfDay(for:Date()))}
    func updateBalanceText(kind:BalanceKind,text:String){let i=ensureTodayBalance();switch kind{case .together:balanceDays[i].togetherText=text;case .family:balanceDays[i].familyText=text;case .selfCare:balanceDays[i].selfText=text};save()}
    func toggleBalance(kind:BalanceKind){let i=ensureTodayBalance();switch kind{case .together:balanceDays[i].togetherDone.toggle();case .family:balanceDays[i].familyDone.toggle();case .selfCare:balanceDays[i].selfDone.toggle()};lastRewardMessage="Mooi. Ook dit hoort bij een goede dag.";playRewardSound();save()}
    func closeWorkday(){guard activeBlock==nil else{return};closedWorkdays.removeAll{Calendar.current.isDateInToday($0.date)};closedWorkdays.append(ClosedWorkday(date:Calendar.current.startOfDay(for:Date()),closedAt:Date()));lastRewardMessage="Werkdag gesloten. De rest mag wachten.";playRewardSound();save()}
    func reopenWorkday(){closedWorkdays.removeAll{Calendar.current.isDateInToday($0.date)};lastRewardMessage=nil;save()}

    // MARK: - Health

    var coffeeTodayCount:Int{coffeeEntries.filter{Calendar.current.isDateInToday($0.date)}.count}
    var recentMedicationPresets:[MedicationPreset]{
        var seen=Set<String>();var result:[MedicationPreset]=[]
        for e in medicationEntries.sorted(by:{$0.date>$1.date}){let key="\(e.name.lowercased())|\(e.dose)|\(e.unit.lowercased())";if !seen.contains(key){seen.insert(key);result.append(MedicationPreset(name:e.name,dose:e.dose,unit:e.unit))};if result.count>=6{break}}
        return result
    }
    func logCoffee(){coffeeEntries.append(CoffeeEntry(date:Date()));save()}
    func undoLastCoffee(){guard let i=coffeeEntries.indices.filter({Calendar.current.isDateInToday(coffeeEntries[$0].date)}).max(by:{coffeeEntries[$0].date<coffeeEntries[$1].date}) else{return};coffeeEntries.remove(at:i);save()}
    func logMedication(name:String,dose:Double,unit:String,note:String=""){let n=clean(name),u=clean(unit);guard !n.isEmpty,dose>0,!u.isEmpty else{return};medicationEntries.append(MedicationEntry(date:Date(),name:n,dose:dose,unit:u,note:clean(note)));save()}
    func deleteMedication(_ e:MedicationEntry){medicationEntries.removeAll{$0.id==e.id};save()}
    func logWellbeing(calm:Int,focus:Int,energy:Int,mood:Int,note:String){wellbeingEntries.append(WellbeingEntry(date:Date(),calm:min(5,max(1,calm)),focus:min(5,max(1,focus)),energy:min(5,max(1,energy)),mood:min(5,max(1,mood)),note:clean(note)));save()}
    func deleteWellbeing(_ e:WellbeingEntry){wellbeingEntries.removeAll{$0.id==e.id};save()}
    func logSleep(sleepHours:Double,fallAsleepMinutes:Int,rested:Int,note:String){sleepEntries.append(SleepEntry(date:Date(),sleepHours:max(0,sleepHours),fallAsleepMinutes:max(0,fallAsleepMinutes),rested:min(5,max(1,rested)),note:clean(note)));save()}
    func deleteSleep(_ e:SleepEntry){sleepEntries.removeAll{$0.id==e.id};save()}

    func healthReport(days: Int) -> String {
        let safe = max(1, days)
        let now = Date()
        let start = Calendar.current.date(
            byAdding: .day,
            value: -(safe - 1),
            to: Calendar.current.startOfDay(for: now)
        ) ?? now

        let meds = medicationEntries.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
        let coffees = coffeeEntries.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
        let checks = wellbeingEntries.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
        let sleeps = sleepEntries.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }

        func avg(_ values: [Double]) -> String {
            guard !values.isEmpty else { return "—" }
            return String(format: "%.1f", values.reduce(0, +) / Double(values.count))
        }

        var lines = [
            "MAARTEN FLOW — GEZONDHEIDSLOG",
            "Periode: \(start.formatted(date: .abbreviated, time: .omitted)) t/m \(now.formatted(date: .abbreviated, time: .omitted))",
            "",
            "SAMENVATTING",
            "Koffie: \(coffees.count) koppen",
            "Slaap gemiddeld: \(avg(sleeps.map { $0.sleepHours })) uur",
            "Inslapen gemiddeld: \(avg(sleeps.map { Double($0.fallAsleepMinutes) })) min",
            "Uitgerust: \(avg(sleeps.map { Double($0.rested) }))/5",
            "Rust in hoofd: \(avg(checks.map { Double($0.calm) }))/5",
            "Focus: \(avg(checks.map { Double($0.focus) }))/5",
            "Energie: \(avg(checks.map { Double($0.energy) }))/5",
            "Stemming: \(avg(checks.map { Double($0.mood) }))/5",
            "",
            "DAGLOG"
        ]

        for offset in 0..<safe {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: start) else { continue }
            let dayMeds = meds.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            let dayCoffee = coffees.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            let dayChecks = checks.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            let daySleeps = sleeps.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }

            guard !dayMeds.isEmpty || !dayCoffee.isEmpty || !dayChecks.isEmpty || !daySleeps.isEmpty else { continue }

            lines.append("")
            lines.append(day.formatted(date: .complete, time: .omitted))

            for sleep in daySleeps {
                lines.append("  Slaap: \(String(format: "%.1f", sleep.sleepHours)) uur · inslapen \(sleep.fallAsleepMinutes) min · uitgerust \(sleep.rested)/5\(sleep.note.isEmpty ? "" : " · \(sleep.note)")")
            }
            for med in dayMeds {
                lines.append("  Medicatie \(med.date.formatted(date: .omitted, time: .shortened)): \(med.name) \(formatDose(med.dose)) \(med.unit)\(med.note.isEmpty ? "" : " · \(med.note)")")
            }
            if !dayCoffee.isEmpty {
                let times = dayCoffee.map { $0.date.formatted(date: .omitted, time: .shortened) }.joined(separator: ", ")
                lines.append("  Koffie: \(dayCoffee.count) · \(times)")
            }
            for check in dayChecks {
                lines.append("  Check-in \(check.date.formatted(date: .omitted, time: .shortened)): rust \(check.calm)/5 · focus \(check.focus)/5 · energie \(check.energy)/5 · stemming \(check.mood)/5\(check.note.isEmpty ? "" : " · \(check.note)")")
            }
        }

        lines.append("")
        lines.append("Dit rapport beschrijft alleen wat is gelogd en geeft geen doserings- of behandeladvies.")
        return lines.joined(separator: "\n")
    }

    func copyHealthReport(days:Int){NSPasteboard.general.clearContents();NSPasteboard.general.setString(healthReport(days:days),forType:.string);lastRewardMessage="Rapport gekopieerd."}

    // MARK: - Helpers

    func clientName(for id:UUID?)->String{guard let id else{return "Niet facturabel"};return clients.first{$0.id==id}?.name ?? "Onbekende klant"}
    func clientName(forProjectID id:UUID?)->String{guard let id,let p=projects.first(where:{$0.id==id}) else{return "Intern"};return clientName(for:p.clientID)}
    func projectName(for id:UUID?)->String{guard let id else{return "Algemeen / intern"};return projects.first{$0.id==id}?.name ?? "Onbekend project"}
    func taskNames(for projectID:UUID?)->[String]{guard let id=projectID,let p=projects.first(where:{$0.id==id}) else{return WorkProject.businessTaskNames};return p.taskNames}
    func billableMinutes(for seconds:TimeInterval)->Int{guard seconds>0 else{return 0};return max(15,Int(ceil((seconds/60)/15))*15)}

    private func makeSession(from b:ActiveWorkBlock,result:WorkBlockResult)->WorkBlock{
        let now=Date(),elapsed=max(0,now.timeIntervalSince(b.startedAt)),focused=max(0,elapsed-b.distractionSeconds)
        return WorkBlock(clientID:b.clientID,projectID:b.projectID,dailyTaskID:b.dailyTaskID,billingUnitID:b.billingUnitID,category:b.category,task:b.task,plannedMinutes:b.plannedMinutes,startedAt:b.startedAt,endedAt:now,distractionSeconds:b.distractionSeconds,focusedSeconds:focused,billableMinutes:b.projectID==nil ? 0:billableMinutes(for:focused),result:result,isRecovery:b.isRecovery)
    }

    private func isStrongFocus(_ b:WorkBlock)->Bool{let target=TimeInterval(max(15,b.plannedMinutes)*60),threshold=min(30*60,max(12*60,target*0.75));return b.focusedSeconds>=threshold}
    private func ensureTodayBalance()->Int{if let i=balanceDays.firstIndex(where:{Calendar.current.isDateInToday($0.date)}){return i};balanceDays.append(BalanceDay(date:Calendar.current.startOfDay(for:Date())));return balanceDays.count-1}
    private func reopenWorkdayIfNeeded(){if isTodayClosed{closedWorkdays.removeAll{Calendar.current.isDateInToday($0.date)}}}
    private func clearOtherDeadlineTasks() {
        for i in dailyTasks.indices where
            Calendar.current.isDateInToday(dailyTasks[i].date) &&
            !dailyTasks[i].isDone &&
            dailyTasks[i].kind == .deadline {
            dailyTasks[i].kind = dailyTasks[i].plannedMinutes <= 5 ? .quick : .normal
        }
    }

    private func suggestionScore(_ p:WorkProject)->Int{
        var score=0
        if parkedItems.contains(where:{$0.projectID==p.id}){score+=40}
        if let d=p.deadline{let days=Calendar.current.dateComponents([.day],from:Calendar.current.startOfDay(for:Date()),to:Calendar.current.startOfDay(for:d)).day ?? 999;if days<=0{score+=50}else if days<=7{score+=35}else if days<=21{score+=20}}
        if p.kind == .wedding && p.weddingStepIndex < weddingCRMStages.count-1{score+=15}
        if p.kind == .business && p.businessStepIndex < businessCRMStages.count-1{score+=8}
        return score
    }

    private func isQuickCRMStage(_ step:String)->Bool{
        let s=step.lowercased()
        return s.contains("brochure")||s.contains("usb")||s.contains("review")||s.contains("gemaild")||s.contains("contact")||s.contains("aanbetaling")||s.contains("gefactureerd")
    }
    private func suggestedMinutesForCRM(_ step:String)->Int{
        let s=step.lowercased()
        if s.contains("ruwe montage"){return 120}
        if s.contains("fijne montage"){return 60}
        if s.contains("opnames"){return 60}
        if s.contains("script")||s.contains("concept"){return 30}
        return 30
    }
    private func categoryForCRM(_ step:String)->String{
        let s=step.lowercased()
        if s.contains("ruwe montage"){return "Ruwe montage"}
        if s.contains("fijne montage"){return "Fijne montage"}
        if s.contains("opnames")||s.contains("gefilmd"){return "Opnames"}
        if s.contains("script"){return "Script"}
        if s.contains("aanpassing"){return "Aanpassingen"}
        if s.contains("aflever")||s.contains("gemaild"){return "Opleveren / export"}
        return "Klantcontact"
    }
    private func normalizedPhase(_ c:String)->String{let x=c.lowercased();if x.contains("ruwe"){return "ruwe"};if x.contains("fijne"){return "fijn"};if x.contains("eind")||x.contains("afrond"){return "eind"};if x.contains("aanpass"){return "aanpassing"};return x}
    private func durationTextLocal(_ m:Int)->String{if m<60{return "\(m) min"};let h=m/60,r=m%60;return r==0 ? "\(h) uur":"\(h)u \(r)m"}
    private func formatDose(_ d:Double)->String{if d.rounded()==d{return String(Int(d))};return String(format:"%.2f",d).replacingOccurrences(of:"0$",with:"")}
    private func clean(_ s:String)->String{s.trimmingCharacters(in:.whitespacesAndNewlines)}
    private func playRewardSound(){if let sound=NSSound(named:NSSound.Name("Glass")){sound.play()}else{NSSound.beep()}}

    private func seedCompanyExamplesIfEmpty(){
        guard companyItems.isEmpty else{return}
        companyItems=[
            CompanyWorkItem(title:"Cursus 1",nextStep:"Volgende les volgen",category:"Leren",defaultMinutes:30),
            CompanyWorkItem(title:"Cursus 2",nextStep:"Volgende les volgen",category:"Leren",defaultMinutes:30),
            CompanyWorkItem(title:"Promo-video's",nextStep:"Eerstvolgende promo een stukje verder brengen",category:"Zichtbaarheid",defaultMinutes:30)
        ]
    }

    private func ensureProjectTasks(index:Int){
        let base=projects[index].kind == .wedding ? WorkProject.weddingTaskNames:WorkProject.businessTaskNames
        for task in base where !projects[index].taskNames.contains(task){projects[index].taskNames.append(task)}
    }

    private func migrateLegacyData(){
        for i in clients.indices {
            let lower = clients[i].name.lowercased()
            if clients[i].kind == .business &&
                (lower.contains("trouw") || lower.contains("bruiloft") || lower.contains("wedding")) {
                clients[i].kind = .wedding
            }
        }

        for i in projects.indices{
            if let client=clients.first(where:{$0.id==projects[i].clientID}){
                if client.kind == .wedding{projects[i].kind = .wedding}
            }
            ensureProjectTasks(index:i)
        }
    }

    private func safelyParkOvernightBlock(){
        guard let b=activeBlock,!Calendar.current.isDateInToday(b.startedAt) else{return}
        parkedItems.removeAll{$0.billingUnitID==b.billingUnitID}
        parkedItems.insert(ParkedWorkItem(clientID:b.clientID,projectID:b.projectID,dailyTaskID:b.dailyTaskID,billingUnitID:b.billingUnitID,category:b.category,task:b.task,plannedMinutes:b.plannedMinutes,resumeNote:"Dit blok stond nog open van gisteren. Hervat bewust vanaf je volgende stap.",parkedAt:Date()),at:0)
        activeBlock=nil;activeDistraction=nil
    }

    private func save(){
        PersistenceController.shared.save(PersistedState(clients:clients,projects:projects,dailyTasks:dailyTasks,workBlocks:workBlocks,activeBlock:activeBlock,parkedItems:parkedItems,activeDistraction:activeDistraction,distractionPeriods:distractionPeriods,balanceDays:balanceDays,closedWorkdays:closedWorkdays,companyItems:companyItems,manualBillingEntries:manualBillingEntries,medicationEntries:medicationEntries,coffeeEntries:coffeeEntries,wellbeingEntries:wellbeingEntries,sleepEntries:sleepEntries))
    }
}
