# Planner Module - Comprehensive Task Management

## Overview
Enhanced planner system dengan semua features yang diperlukan untuk task management yang professional.

## Features

### ✅ Core Features
- **Task Management**: Create, read, update, delete tasks
- **Task Details**: Description, notes, attachments
- **Subtasks/Checklist**: Break down tasks into smaller items dengan progress tracking
- **Recurring Tasks**: Daily, weekly, monthly, yearly patterns dengan auto-generation
- **Categories**: Organize tasks dengan categories dan colors
- **Projects**: Group related tasks dalam projects
- **Tags**: Flexible tagging system untuk better organization
- **Time Tracking**: Estimated vs actual time spent
- **Comments**: Add comments untuk collaboration
- **Status Management**: open, in_progress, done, snoozed, cancelled

### ✅ Views
1. **List View**: Traditional list dengan filtering
2. **Calendar View**: Monthly calendar dengan task markers
3. **Kanban View**: Drag & drop board (To Do → In Progress → Done)

### ✅ Organization
- **Categories Management**: Create, edit, delete categories dengan colors
- **Projects Management**: Create, archive, delete projects
- **Templates**: Create task templates untuk common patterns

### ✅ Advanced Features
- **Search**: Full-text search dalam tasks
- **Filtering**: Filter by category, project, status, priority
- **Auto Tasks**: Auto-generated tasks dari business events (low stock, PO, bookings, claims, expiry)
- **Dependencies**: Task dependencies (blocked by, blocks)
- **Sharing**: Share tasks dengan other users (future)

## Database Schema

### Tables
- `planner_tasks` - Main tasks table dengan semua fields
- `planner_categories` - Task categories
- `planner_projects` - Project grouping
- `planner_task_templates` - Task templates

### Key Fields
- `subtasks` (JSONB) - Array of subtask objects
- `comments` (JSONB) - Array of comment objects
- `tags` (TEXT[]) - Array of tag strings
- `recurrence_*` - Fields untuk recurring tasks
- `time_spent_minutes` - Time tracking
- `depends_on_task_ids` - Task dependencies

## Usage

### Navigation
```dart
Navigator.pushNamed(context, '/planner');
```

### Create Task
```dart
final task = await repo.createTask(
  title: 'My Task',
  description: 'Task description',
  dueAt: DateTime.now(),
  priority: 'high',
  categoryId: categoryId,
  projectId: projectId,
);
```

### Update Task
```dart
await repo.updateTask(taskId, {
  'status': 'in_progress',
  'time_spent_minutes': 30,
});
```

## Migration

Run migration file:
```sql
-- db/migrations/2025-12-08_enhance_planner_tasks.sql
```

This will:
- Add all new columns to planner_tasks
- Create categories, projects, templates tables
- Add indexes untuk performance
- Create triggers untuk recurring tasks

## Next Steps (Future Enhancements)
- Drag & drop untuk kanban view
- Task attachments (file upload)
- Task sharing/collaboration
- Task analytics/reports
- Mobile notifications untuk reminders
- Task dependencies visualization
- Gantt chart view


