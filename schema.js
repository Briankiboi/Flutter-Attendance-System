// Users Collection
const userSchema = {
  userId: '',          // String - Primary key
  email: '',          // String - Unique, indexed
  name: '',           // String
  passwordHash: '',    // String
  role: '',           // String - 'lecturer' or 'student'
  departmentId: '',    // String - Foreign key
  courseId: '',        // String - Foreign key (for students only)
  createdAt: null,     // Timestamp
  emailVerified: false, // Boolean
  lastLogin: null,      // Timestamp - for tracking login activity
  status: 'inactive'    // String - 'active' or 'inactive'
};

// Departments Collection
const departmentSchema = {
  departmentId: '',    // String - Primary key
  departmentName: '',  // String - Unique, indexed
  departmentCode: '',  // String - for short codes
  active: true        // Boolean - for department status
};

// Courses Collection
const courseSchema = {
  courseId: '',       // String - Primary key
  courseName: '',     // String - Unique within department
  departmentId: '',   // String - Foreign key
  courseCode: '',     // String - course code
  duration: 0,        // Number - course duration in years
  active: true       // Boolean - course status
};

// Units Collection
const unitSchema = {
  unitId: '',        // String - Primary key
  unitName: '',      // String - Unique within course
  unitCode: '',      // String - Unique, indexed
  courseId: '',      // String - Foreign key
  semester: 0,       // Number - semester number
  credits: 0,        // Number - unit credits
  lecturerId: ''     // String - link to lecturer
};

// Attendance Collection
const attendanceSchema = {
  attendanceId: '',   // String - Primary key
  userId: '',         // String - Foreign key
  unitId: '',         // String - Foreign key
  sessionId: '',      // String - group attendance by session
  attendanceTime: null, // Timestamp
  qrCode: '',         // String
  status: 'absent',   // String - 'present', 'late', or 'absent'
  location: ''        // String - attendance location
};

// Sessions Collection
const sessionSchema = {
  sessionId: '',      // String - Primary key
  unitId: '',         // String - Foreign key
  lecturerId: '',     // String - Foreign key
  startTime: null,    // Timestamp
  endTime: null,      // Timestamp
  qrCode: '',         // String
  status: 'scheduled' // String - 'scheduled', 'active', or 'completed'
};

// Export schemas for use in other files
module.exports = {
  userSchema,
  departmentSchema,
  courseSchema,
  unitSchema,
  attendanceSchema,
  sessionSchema
}; 