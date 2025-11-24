// OpenAI Function Schema for GPT Integration
// This defines the strongly-typed function signatures that GPT can call

export const openAIFunctionSchema = {
  tools: [
    {
      type: 'function' as const,
      function: {
        name: 'list_reminder_lists',
        description: 'List all reminder lists available on the device.',
        parameters: {
          type: 'object' as const,
          properties: {},
          required: [],
        },
      },
    },
    {
      type: 'function' as const,
      function: {
        name: 'list_reminder_tasks',
        description: 'List tasks/reminders, optionally filtered by list or completion status.',
        parameters: {
          type: 'object' as const,
          properties: {
            list_id: {
              type: 'string' as const,
              description:
                'Optional: Filter by specific list ID. Get valid list IDs by calling list_reminder_lists first. The ID is the "id" field from the ReminderList objects returned by that function. If omitted, returns tasks from all lists.',
            },
            status: {
              type: 'string' as const,
              enum: ['needsAction', 'completed'],
              description:
                'Optional: Filter by completion status. "needsAction" = incomplete, "completed" = done.',
            },
          },
          required: [],
        },
      },
    },
    {
      type: 'function' as const,
      function: {
        name: 'create_reminder_task',
        description: 'Create a new reminder task.',
        parameters: {
          type: 'object' as const,
          properties: {
            title: {
              type: 'string' as const,
              description: 'The title/name of the reminder.',
            },
            notes: {
              type: 'string' as const,
              description: 'Optional: Additional notes or description.',
            },
            list_id: {
              type: 'string' as const,
              description:
                'Optional: ID of the reminder list to add the task to. Get valid list IDs by calling list_reminder_lists first. The ID is the "id" field from the ReminderList objects returned by that function. If omitted, uses the device\'s default reminder list.',
            },
            remind_me_date: {
              type: 'string' as const,
              format: 'date',
              description:
                'Optional: The date to associate with this task (YYYY-MM-DD). Covers "do X by DATE" or "remind me on DATE". Example: "2025-11-24". If omitted but time is provided, defaults to today.',
            },
            remind_me_time: {
              type: 'string' as const,
              description:
                'Optional: The time to associate with this task (HH:mm:ss). Example: "14:30:00". If omitted, the task is associated with the whole day.',
            },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function' as const,
      function: {
        name: 'update_reminder_task',
        description: 'Update an existing reminder task.',
        parameters: {
          type: 'object' as const,
          properties: {
            task_id: {
              type: 'string' as const,
              description: 'The ID of the task to update.',
            },
            title: {
              type: 'string' as const,
              description: 'Optional: New title for the task.',
            },
            notes: {
              type: 'string' as const,
              description: 'Optional: New notes for the task.',
            },
            remind_me_date: {
              type: 'string' as const,
              format: 'date',
              description: 'Optional: New date to associate with this task (YYYY-MM-DD).',
            },
            remind_me_time: {
              type: 'string' as const,
              description: 'Optional: New time to associate with this task (HH:mm:ss).',
            },
          },
          required: ['task_id'],
        },
      },
    },
    {
      type: 'function' as const,
      function: {
        name: 'complete_reminder_task',
        description: 'Mark a reminder task as completed.',
        parameters: {
          type: 'object' as const,
          properties: {
            task_id: {
              type: 'string' as const,
              description: 'The ID of the task to mark as completed.',
            },
          },
          required: ['task_id'],
        },
      },
    },
    {
      type: 'function' as const,
      function: {
        name: 'delete_reminder_task',
        description: 'Delete a reminder task.',
        parameters: {
          type: 'object' as const,
          properties: {
            task_id: {
              type: 'string' as const,
              description: 'The ID of the task to delete.',
            },
          },
          required: ['task_id'],
        },
      },
    },
  ],
};
