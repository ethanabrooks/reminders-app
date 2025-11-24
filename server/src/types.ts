// Shared types for iOS app <-> Server communication

export type TaskStatus = 'needsAction' | 'completed';

export interface NormalizedTask {
  id: string; // EventKit reminder.calendarItemIdentifier
  listId: string; // EKCalendar.calendarIdentifier
  title: string;
  notes?: string;
  status: TaskStatus;
  dueISO?: string; // RFC3339
  completedISO?: string;
  url?: string; // app deeplink (e.g., myapp://task/<id>)
}

export interface ReminderList {
  id: string;
  title: string;
}

export type CommandKind =
  | 'list_lists'
  | 'list_tasks'
  | 'create_task'
  | 'update_task'
  | 'complete_task'
  | 'delete_task';

export interface CommandEnvelope<T = any> {
  id: string; // server command id
  kind: CommandKind;
  payload: T;
  iat: number; // issued at
  exp: number; // short TTL (e.g., 60s)
}

// Payloads for each command type
export interface ListTasksPayload {
  list_id?: string;
  status?: TaskStatus;
}

export interface CreateTaskPayload {
  title: string;
  notes?: string;
  list_id?: string;
  due_iso?: string;
}

export interface UpdateTaskPayload {
  task_id: string;
  title?: string;
  notes?: string;
  due_iso?: string;
}

export interface CompleteTaskPayload {
  task_id: string;
}

export interface DeleteTaskPayload {
  task_id: string;
}

// Device registration
export interface DeviceInfo {
  apnsToken: string;
  userId: string;
  registeredAt: number;
}

// Command result from device
export interface CommandResult {
  commandId: string;
  success: boolean;
  result?: any;
  error?: string;
  timestamp: number;
}
