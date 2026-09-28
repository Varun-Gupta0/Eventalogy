import { Annotation, messagesStateReducer } from "@langchain/langgraph";
import { BaseMessage } from "@langchain/core/messages";

// ─── Domain Types ──────────────────────────────────────────────────────────────

export interface EventRequirements {
  eventType?: string;
  guestCount?: number;
  location?: string;
  dateStr?: string;
  budgetStr?: string;
  preferences?: string[];
  constraints?: string[];
}

export interface EventPlan {
  title: string;
  summary: string;
  requiredServices: string[];
  venueCharacteristics: string[];
  estimatedInitialBudget: number;
  dependencies: string[];
}

export interface CandidateVenue {
  venueId: string;
  name: string;
  city: string;
  capacity: number;
  venueType: string;
  basePrice?: number;
  amenities?: string[];
  score?: number; // LLM-assigned relevance score
}

export interface CandidateVendor {
  vendorId: string;
  name: string;
  serviceCategory: string;
  city: string;
  rating?: number;
  priceRange?: string;
  score?: number; // LLM-assigned relevance score
}

export interface ResolvedService {
  serviceId: string;
  name: string;
  categoryId: string;
  categoryName: string;
  vendorId?: string; // resolved after vendor_agent
}

export interface AvailabilityResult {
  venueId: string;
  available: boolean;
  conflictingBookingIds?: string[];
}

export interface VendorAvailabilityResult {
  vendorId: string;
  serviceId: string;
  available: boolean;
  conflictingAllocationIds?: string[];
}

export interface BudgetLineItem {
  category: string;         // e.g., "Venue", "Catering", "Photography"
  vendorId?: string;
  venueId?: string;
  description: string;
  estimatedCost: number;
}

export interface BudgetBreakdown {
  totalEstimatedCost: number;
  lineItems: BudgetLineItem[];
  withinBudget: boolean;
  overageAmount?: number;
  notes: string;
}

export interface Recommendation {
  type: "venue" | "vendor" | "package";
  entityId: string;
  name: string;
  reason: string;
  estimatedCost: number;
}

export interface ApprovalRequest {
  approvalId: string;
  workflowId: string;
  summary: string;
  recommendedVenueId?: string;
  recommendedVenueName?: string;
  recommendedVendors: { vendorId: string; name: string; serviceCategory: string; estimatedCost: number }[];
  totalEstimatedCost: number;
  budgetBreakdown: BudgetBreakdown | null;
  status: "pending" | "approved" | "rejected";
  userDecision?: string; // freeform user note on approval
  requestedAt?: string;
  decidedAt?: string;
}

export interface AgentHistoryEntry {
  agent: string;
  stage: string;
  status: "success" | "error" | "skipped";
  startedAt: string;
  durationMs?: number;
  notes?: string;
}

// ─── Enums ────────────────────────────────────────────────────────────────────

export type WorkflowStage =
  | "intake"
  | "planning"
  | "specialist_search"
  | "availability"
  | "budget"
  | "approval_pending"
  | "booking"
  | "communication"
  | "completed";

export type WorkflowStatus = "active" | "pending_user" | "completed" | "error";

// ─── Graph State ──────────────────────────────────────────────────────────────

export const GraphState = Annotation.Root({
  // ── Identity ──
  workflowId: Annotation<string>(),
  conversationId: Annotation<string>(),
  userId: Annotation<string>(),
  eventId: Annotation<string | null>(),

  // ── Routing ──
  currentAgent: Annotation<string>(),
  currentStage: Annotation<WorkflowStage>(),

  // ── Conversation ──
  userMessage: Annotation<string>(),
  conversationHistory: Annotation<BaseMessage[]>({
    reducer: messagesStateReducer,
    default: () => [],
  }),

  // ── Intake ──
  eventRequirements: Annotation<EventRequirements>({
    reducer: (curr, update) => ({ ...curr, ...update }),
    default: () => ({}),
  }),
  missingInformation: Annotation<string[]>(),
  pendingQuestions: Annotation<string[]>(),
  intakeComplete: Annotation<boolean>(),

  // ── Planning ──
  eventPlan: Annotation<EventPlan | null>(),
  aiPlanId: Annotation<string | null>(),

  // ── Specialist Search ──
  resolvedServiceIds: Annotation<ResolvedService[]>(),
  resolvedPackageIds: Annotation<string[]>(),
  candidateVenues: Annotation<CandidateVenue[]>(),
  candidateVendors: Annotation<CandidateVendor[]>(),

  // ── Availability ──
  availabilityResults: Annotation<AvailabilityResult[]>(),
  vendorAvailabilityResults: Annotation<VendorAvailabilityResult[]>(),
  availableVenueIds: Annotation<string[]>(),
  availableVendorIds: Annotation<string[]>(),

  // ── Budget ──
  budgetBreakdown: Annotation<BudgetBreakdown | null>(),
  budgetSufficient: Annotation<boolean>(),
  pricingResults: Annotation<Record<string, number>>(),

  // ── Recommendations ──
  recommendations: Annotation<Recommendation[]>(),
  selectedVenueId: Annotation<string | null>(),
  selectedVendorIds: Annotation<string[]>(),

  // ── Approval ──
  pendingApprovals: Annotation<ApprovalRequest[]>(),
  approvalStatus: Annotation<"none" | "pending" | "approved" | "rejected">(),

  // ── Execution ──
  createdEnquiryIds: Annotation<string[]>({
    reducer: (curr, update) => [...new Set([...curr, ...update])],
    default: () => [],
  }),
  createdBookingIds: Annotation<string[]>({
    reducer: (curr, update) => [...new Set([...curr, ...update])],
    default: () => [],
  }),
  createdAllocationIds: Annotation<string[]>({
    reducer: (curr, update) => [...new Set([...curr, ...update])],
    default: () => [],
  }),

  // ── System ──
  agentHistory: Annotation<AgentHistoryEntry[]>({
    reducer: (curr, update) => curr.concat(update),
    default: () => [],
  }),
  completedTasks: Annotation<string[]>({
    reducer: (curr, update) => [...new Set([...curr, ...update])],
    default: () => [],
  }),
  failedTasks: Annotation<string[]>({
    reducer: (curr, update) => [...new Set([...curr, ...update])],
    default: () => [],
  }),
  retryCount: Annotation<number>(),
  workflowStatus: Annotation<WorkflowStatus>(),
  lastError: Annotation<string | null>(),
  metadata: Annotation<Record<string, any>>({
    reducer: (curr, update) => ({ ...curr, ...update }),
    default: () => ({}),
  }),
});

export type StateType = typeof GraphState.State;
