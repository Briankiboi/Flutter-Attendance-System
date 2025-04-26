// Recommended indexes for optimal query performance
{
  "indexes": [
    {
      "collectionGroup": "attendance",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "unitId", "order": "ASCENDING" },
        { "fieldPath": "attendanceTime", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "sessions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "lecturerId", "order": "ASCENDING" },
        { "fieldPath": "startTime", "order": "DESCENDING" }
      ]
    }
  ]
} 