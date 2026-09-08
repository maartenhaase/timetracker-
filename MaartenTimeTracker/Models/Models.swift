import Foundation

enum ClientKind: String, Codable, CaseIterable, Identifiable {
    case wedding = "Bruiloft"
    case business = "Zakelijk"
    var id: String { rawValue }
}

enum ProjectKind: String, Codable, CaseIterable {
    case wedding
    case business
}

struct Client: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var kind: ClientKind = .business
    var email: String = ""
    var phone: String = ""
    var isArchived: Bool = false

    enum CodingKeys: String, CodingKey { case id, name, kind, email, phone, isArchived }

    init(id: UUID = UUID(), name: String, kind: ClientKind = .business, email: String = "", phone: String = "", isArchived: Bool = false) {
        self.id = id; self.name = name; self.kind = kind; self.email = email; self.phone = phone; self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Klant"
        kind = try c.decodeIfPresent(ClientKind.self, forKey: .kind) ?? .business
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}

struct WorkProject: Identifiable, Codable, Hashable {
    static let weddingTaskNames = [
        "Klantcontact",
        "Concepting / voorwerk",
        "Opnames",
        "Ruwe montage",
        "Fijne montage",
        "Eindmontage / afronden",
        "Aanpassingen",
        "Opleveren / export",
        "Extra's"
    ]

    static let businessTaskNames = [
        "Contact / briefing",
        "Concepting / voorwerk",
        "Script",
        "Opnames",
        "Montage",
        "Aflevering",
        "Aanpassingsronde",
        "Meerwerk / extra / upsell"
    ]

    static let standardTaskNames = weddingTaskNames

    var id: UUID = UUID()
    var clientID: UUID
    var name: String
    var kind: ProjectKind = .business
    var isArchived: Bool = false
    var taskNames: [String] = []
    var deadline: Date? = nil
    var weddingDate: Date? = nil
    var weddingStepIndex: Int = 0
    var businessStepIndex: Int = 0
    var businessRevisionCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, clientID, name, kind, isArchived, taskNames, deadline, weddingDate, weddingStepIndex, businessStepIndex, businessRevisionCount
    }

    init(
        id: UUID = UUID(),
        clientID: UUID,
        name: String,
        kind: ProjectKind = .business,
        isArchived: Bool = false,
        taskNames: [String] = [],
        deadline: Date? = nil,
        weddingDate: Date? = nil,
        weddingStepIndex: Int = 0,
        businessStepIndex: Int = 0,
        businessRevisionCount: Int = 0
    ) {
        self.id = id; self.clientID = clientID; self.name = name; self.kind = kind; self.isArchived = isArchived
        self.taskNames = taskNames.isEmpty ? (kind == .wedding ? Self.weddingTaskNames : Self.businessTaskNames) : taskNames
        self.deadline = deadline; self.weddingDate = weddingDate; self.weddingStepIndex = weddingStepIndex; self.businessStepIndex = businessStepIndex; self.businessRevisionCount = businessRevisionCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        clientID = try c.decode(UUID.self, forKey: .clientID)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Project"
        kind = try c.decodeIfPresent(ProjectKind.self, forKey: .kind) ?? .business
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        let decodedTasks = try c.decodeIfPresent([String].self, forKey: .taskNames) ?? []
        taskNames = decodedTasks.isEmpty ? (kind == .wedding ? Self.weddingTaskNames : Self.businessTaskNames) : decodedTasks
        deadline = try c.decodeIfPresent(Date.self, forKey: .deadline)
        weddingDate = try c.decodeIfPresent(Date.self, forKey: .weddingDate)
        weddingStepIndex = try c.decodeIfPresent(Int.self, forKey: .weddingStepIndex) ?? 0
        businessStepIndex = try c.decodeIfPresent(Int.self, forKey: .businessStepIndex) ?? 0
        businessRevisionCount = try c.decodeIfPresent(Int.self, forKey: .businessRevisionCount) ?? 0
    }
}

enum DailyTaskKind: String, Codable, CaseIterable {
    case quick
    case deadline
    case normal
    case company
}

struct DailyTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID?
    var title: String
    var category: String
    var date: Date
    var plannedMinutes: Int
    var isDone: Bool = false
    var completedAt: Date? = nil
    var billingUnitID: UUID
    var kind: DailyTaskKind = .normal
    var deadline: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, projectID, title, category, date, plannedMinutes, isDone, completedAt, billingUnitID, kind, deadline
    }

    init(
        id: UUID = UUID(),
        projectID: UUID?,
        title: String,
        category: String,
        date: Date,
        plannedMinutes: Int,
        isDone: Bool = false,
        completedAt: Date? = nil,
        billingUnitID: UUID? = nil,
        kind: DailyTaskKind = .normal,
        deadline: Date? = nil
    ) {
        self.id = id; self.projectID = projectID; self.title = title; self.category = category; self.date = date
        self.plannedMinutes = plannedMinutes; self.isDone = isDone; self.completedAt = completedAt
        self.billingUnitID = billingUnitID ?? id; self.kind = kind; self.deadline = deadline
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        projectID = try c.decodeIfPresent(UUID.self, forKey: .projectID)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Werk"
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "Extra's"
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        plannedMinutes = try c.decodeIfPresent(Int.self, forKey: .plannedMinutes) ?? 30
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        billingUnitID = try c.decodeIfPresent(UUID.self, forKey: .billingUnitID) ?? id
        kind = try c.decodeIfPresent(DailyTaskKind.self, forKey: .kind) ?? (plannedMinutes <= 5 ? .quick : .normal)
        deadline = try c.decodeIfPresent(Date.self, forKey: .deadline)
    }
}

struct CompanyWorkItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var nextStep: String = ""
    var category: String = "Bedrijf bouwen"
    var defaultMinutes: Int = 30
    var isArchived: Bool = false
    var lastWorkedAt: Date? = nil
}

struct CRMStage: Identifiable, Hashable {
    var id: Int { index }
    var index: Int
    var title: String
}

let weddingCRMStages: [String] = [
    "Aanvraag binnen",
    "Brochure gestuurd",
    "Kennismaking ingepland",
    "Kennismaking gehad",
    "Kennismaking uitgewerkt",
    "Akkoord",
    "Aanbetaling",
    "USB-stick besteld",
    "Contactmoment ingepland",
    "Formulier ingevuld",
    "Contactmoment gehad",
    "Bruiloft gefilmd",
    "Ruwe montage gedaan",
    "Fijne montage gedaan",
    "Eindmontage / afronden gedaan",
    "Film gemaild",
    "Akkoord van de film",
    "Rest gefactureerd",
    "USB-stick gemaakt en opgestuurd",
    "Gevraagd om review"
]

let businessCRMStages: [String] = [
    "Contact / briefing",
    "Opdracht duidelijk",
    "Concept / script akkoord",
    "Opnames",
    "Eerste montage",
    "Eerste aflevering",
    "Aanpassingsronde(n)",
    "Definitief geleverd",
    "Meerwerk / upsell",
    "Gefactureerd / afgerond"
]

struct ActiveWorkBlock: Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID?
    var projectID: UUID?
    var dailyTaskID: UUID?
    var billingUnitID: UUID
    var category: String
    var task: String
    var plannedMinutes: Int
    var startedAt: Date
    var distractionSeconds: TimeInterval = 0
    var isRecovery: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, clientID, projectID, dailyTaskID, billingUnitID, category, task, plannedMinutes, startedAt, distractionSeconds, isRecovery
    }

    init(id: UUID = UUID(), clientID: UUID?, projectID: UUID?, dailyTaskID: UUID?, billingUnitID: UUID, category: String, task: String, plannedMinutes: Int, startedAt: Date = Date(), distractionSeconds: TimeInterval = 0, isRecovery: Bool = false) {
        self.id=id; self.clientID=clientID; self.projectID=projectID; self.dailyTaskID=dailyTaskID; self.billingUnitID=billingUnitID
        self.category=category; self.task=task; self.plannedMinutes=plannedMinutes; self.startedAt=startedAt; self.distractionSeconds=distractionSeconds; self.isRecovery=isRecovery
    }

    init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decodeIfPresent(UUID.self,forKey:.id) ?? UUID()
        clientID=try c.decodeIfPresent(UUID.self,forKey:.clientID)
        projectID=try c.decodeIfPresent(UUID.self,forKey:.projectID)
        dailyTaskID=try c.decodeIfPresent(UUID.self,forKey:.dailyTaskID)
        billingUnitID=try c.decodeIfPresent(UUID.self,forKey:.billingUnitID) ?? dailyTaskID ?? id
        category=try c.decodeIfPresent(String.self,forKey:.category) ?? "Werk"
        task=try c.decodeIfPresent(String.self,forKey:.task) ?? category
        plannedMinutes=try c.decodeIfPresent(Int.self,forKey:.plannedMinutes) ?? 30
        startedAt=try c.decodeIfPresent(Date.self,forKey:.startedAt) ?? Date()
        distractionSeconds=try c.decodeIfPresent(TimeInterval.self,forKey:.distractionSeconds) ?? 0
        isRecovery=try c.decodeIfPresent(Bool.self,forKey:.isRecovery) ?? false
    }
}

enum WorkBlockResult: String, Codable, Hashable { case done, stopped, parked }

struct WorkBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID?
    var projectID: UUID?
    var dailyTaskID: UUID?
    var billingUnitID: UUID
    var category: String
    var task: String
    var plannedMinutes: Int
    var startedAt: Date
    var endedAt: Date
    var distractionSeconds: TimeInterval
    var focusedSeconds: TimeInterval
    var billableMinutes: Int
    var result: WorkBlockResult
    var invoiced: Bool = false
    var isRecovery: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, clientID, projectID, dailyTaskID, billingUnitID, category, task, plannedMinutes, startedAt, endedAt, distractionSeconds, focusedSeconds, billableMinutes, result, invoiced, isRecovery
    }

    init(id: UUID = UUID(), clientID: UUID?, projectID: UUID?, dailyTaskID: UUID?, billingUnitID: UUID, category: String, task: String, plannedMinutes: Int, startedAt: Date, endedAt: Date, distractionSeconds: TimeInterval, focusedSeconds: TimeInterval, billableMinutes: Int, result: WorkBlockResult, invoiced: Bool = false, isRecovery: Bool = false) {
        self.id=id; self.clientID=clientID; self.projectID=projectID; self.dailyTaskID=dailyTaskID; self.billingUnitID=billingUnitID
        self.category=category; self.task=task; self.plannedMinutes=plannedMinutes; self.startedAt=startedAt; self.endedAt=endedAt
        self.distractionSeconds=distractionSeconds; self.focusedSeconds=focusedSeconds; self.billableMinutes=billableMinutes; self.result=result; self.invoiced=invoiced; self.isRecovery=isRecovery
    }

    init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decodeIfPresent(UUID.self,forKey:.id) ?? UUID()
        clientID=try c.decodeIfPresent(UUID.self,forKey:.clientID)
        projectID=try c.decodeIfPresent(UUID.self,forKey:.projectID)
        dailyTaskID=try c.decodeIfPresent(UUID.self,forKey:.dailyTaskID)
        billingUnitID=try c.decodeIfPresent(UUID.self,forKey:.billingUnitID) ?? dailyTaskID ?? id
        category=try c.decodeIfPresent(String.self,forKey:.category) ?? "Werk"
        task=try c.decodeIfPresent(String.self,forKey:.task) ?? category
        plannedMinutes=try c.decodeIfPresent(Int.self,forKey:.plannedMinutes) ?? 30
        startedAt=try c.decodeIfPresent(Date.self,forKey:.startedAt) ?? Date()
        endedAt=try c.decodeIfPresent(Date.self,forKey:.endedAt) ?? startedAt
        distractionSeconds=try c.decodeIfPresent(TimeInterval.self,forKey:.distractionSeconds) ?? 0
        focusedSeconds=try c.decodeIfPresent(TimeInterval.self,forKey:.focusedSeconds) ?? 0
        billableMinutes=try c.decodeIfPresent(Int.self,forKey:.billableMinutes) ?? 0
        result=try c.decodeIfPresent(WorkBlockResult.self,forKey:.result) ?? .stopped
        invoiced=try c.decodeIfPresent(Bool.self,forKey:.invoiced) ?? false
        isRecovery=try c.decodeIfPresent(Bool.self,forKey:.isRecovery) ?? false
    }
}

struct ParkedWorkItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID?
    var projectID: UUID?
    var dailyTaskID: UUID?
    var billingUnitID: UUID
    var category: String
    var task: String
    var plannedMinutes: Int
    var resumeNote: String
    var parkedAt: Date
}

struct ActiveDistraction: Codable, Hashable { var startedAt: Date }

struct DistractionPeriod: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var startedAt: Date
    var endedAt: Date
    var task: String
    var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }
}

enum BalanceKind: String, CaseIterable, Identifiable {
    case together, family, selfCare
    var id:String{rawValue}
    var title:String{ switch self {case .together:return "Samen"; case .family:return "Gezin"; case .selfCare:return "Zelf"}}
    var icon:String{ switch self {case .together:return "heart"; case .family:return "house"; case .selfCare:return "leaf"}}
}

struct BalanceDay: Identifiable, Codable, Hashable {
    var id:UUID=UUID(); var date:Date
    var togetherText:String=""; var familyText:String=""; var selfText:String=""
    var togetherDone:Bool=false; var familyDone:Bool=false; var selfDone:Bool=false
}

struct ClosedWorkday: Identifiable, Codable, Hashable { var id:UUID=UUID(); var date:Date; var closedAt:Date }

struct ManualBillingEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID
    var projectID: UUID?
    var date: Date
    var description: String
    var minutes: Int
    var invoiced: Bool = false
}

struct BillingUnitSummary: Identifiable, Hashable {
    var id:UUID; var clientID:UUID; var projectID:UUID; var category:String; var task:String; var firstDate:Date; var focusedSeconds:TimeInterval; var billableMinutes:Int
}
struct BillingProjectSummary: Identifiable, Hashable {
    var id:UUID{projectID}; var clientID:UUID; var projectID:UUID; var units:[BillingUnitSummary]; var totalBillableMinutes:Int
}

struct MedicationEntry: Identifiable, Codable, Hashable { var id:UUID=UUID(); var date:Date; var name:String; var dose:Double; var unit:String; var note:String="" }
struct CoffeeEntry: Identifiable, Codable, Hashable { var id:UUID=UUID(); var date:Date }
struct WellbeingEntry: Identifiable, Codable, Hashable { var id:UUID=UUID(); var date:Date; var calm:Int; var focus:Int; var energy:Int; var mood:Int; var note:String="" }
struct SleepEntry: Identifiable, Codable, Hashable { var id:UUID=UUID(); var date:Date; var sleepHours:Double; var fallAsleepMinutes:Int; var rested:Int; var note:String="" }
struct MedicationPreset: Identifiable, Hashable { var id:String{"\(name)|\(dose)|\(unit)"}; var name:String; var dose:Double; var unit:String }

struct PersistedState: Codable {
    var clients:[Client]; var projects:[WorkProject]; var dailyTasks:[DailyTask]; var workBlocks:[WorkBlock]
    var activeBlock:ActiveWorkBlock?; var parkedItems:[ParkedWorkItem]; var activeDistraction:ActiveDistraction?
    var distractionPeriods:[DistractionPeriod]; var balanceDays:[BalanceDay]; var closedWorkdays:[ClosedWorkday]
    var companyItems:[CompanyWorkItem]; var manualBillingEntries:[ManualBillingEntry]
    var medicationEntries:[MedicationEntry]; var coffeeEntries:[CoffeeEntry]; var wellbeingEntries:[WellbeingEntry]; var sleepEntries:[SleepEntry]

    init(
        clients:[Client]=[], projects:[WorkProject]=[], dailyTasks:[DailyTask]=[], workBlocks:[WorkBlock]=[],
        activeBlock:ActiveWorkBlock?=nil, parkedItems:[ParkedWorkItem]=[], activeDistraction:ActiveDistraction?=nil,
        distractionPeriods:[DistractionPeriod]=[], balanceDays:[BalanceDay]=[], closedWorkdays:[ClosedWorkday]=[],
        companyItems:[CompanyWorkItem]=[], manualBillingEntries:[ManualBillingEntry]=[],
        medicationEntries:[MedicationEntry]=[], coffeeEntries:[CoffeeEntry]=[], wellbeingEntries:[WellbeingEntry]=[], sleepEntries:[SleepEntry]=[]
    ){
        self.clients=clients; self.projects=projects; self.dailyTasks=dailyTasks; self.workBlocks=workBlocks; self.activeBlock=activeBlock
        self.parkedItems=parkedItems; self.activeDistraction=activeDistraction; self.distractionPeriods=distractionPeriods
        self.balanceDays=balanceDays; self.closedWorkdays=closedWorkdays; self.companyItems=companyItems; self.manualBillingEntries=manualBillingEntries
        self.medicationEntries=medicationEntries; self.coffeeEntries=coffeeEntries; self.wellbeingEntries=wellbeingEntries; self.sleepEntries=sleepEntries
    }

    enum CodingKeys:String,CodingKey {
        case clients,projects,dailyTasks,workBlocks,activeBlock,parkedItems,activeDistraction,distractionPeriods,balanceDays,closedWorkdays
        case companyItems,manualBillingEntries,medicationEntries,coffeeEntries,wellbeingEntries,sleepEntries
    }

    init(from decoder:Decoder)throws{
        let c=try decoder.container(keyedBy:CodingKeys.self)
        clients=try c.decodeIfPresent([Client].self,forKey:.clients) ?? []
        projects=try c.decodeIfPresent([WorkProject].self,forKey:.projects) ?? []
        dailyTasks=try c.decodeIfPresent([DailyTask].self,forKey:.dailyTasks) ?? []
        workBlocks=try c.decodeIfPresent([WorkBlock].self,forKey:.workBlocks) ?? []
        activeBlock=try c.decodeIfPresent(ActiveWorkBlock.self,forKey:.activeBlock)
        parkedItems=try c.decodeIfPresent([ParkedWorkItem].self,forKey:.parkedItems) ?? []
        activeDistraction=try c.decodeIfPresent(ActiveDistraction.self,forKey:.activeDistraction)
        distractionPeriods=try c.decodeIfPresent([DistractionPeriod].self,forKey:.distractionPeriods) ?? []
        balanceDays=try c.decodeIfPresent([BalanceDay].self,forKey:.balanceDays) ?? []
        closedWorkdays=try c.decodeIfPresent([ClosedWorkday].self,forKey:.closedWorkdays) ?? []
        companyItems=try c.decodeIfPresent([CompanyWorkItem].self,forKey:.companyItems) ?? []
        manualBillingEntries=try c.decodeIfPresent([ManualBillingEntry].self,forKey:.manualBillingEntries) ?? []
        medicationEntries=try c.decodeIfPresent([MedicationEntry].self,forKey:.medicationEntries) ?? []
        coffeeEntries=try c.decodeIfPresent([CoffeeEntry].self,forKey:.coffeeEntries) ?? []
        wellbeingEntries=try c.decodeIfPresent([WellbeingEntry].self,forKey:.wellbeingEntries) ?? []
        sleepEntries=try c.decodeIfPresent([SleepEntry].self,forKey:.sleepEntries) ?? []
    }
}
