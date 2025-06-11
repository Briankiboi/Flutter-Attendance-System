// Flutter web configuration
window.flutterWebRenderer = "html";
window.enableDartProfiling = false;

// Optimize memory usage
const dartMaxOldSpaceSize = 2048; // 2GB max memory
if (typeof window.dartMaxOldSpaceSize === 'undefined') {
  window.dartMaxOldSpaceSize = dartMaxOldSpaceSize;
}

// Disable debugging in production
if (window.location.hostname !== 'localhost') {
  console.log = function() {};
  console.warn = function() {};
  console.error = function() {};
} 