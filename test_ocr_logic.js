// Quick test script for OCR logic improvements
// Run with: node test_ocr_logic.js

/**
 * Normalize amount string to number
 * Handles: 1,234.50 (comma as thousand separator) and 1234.50
 */
function normalizeAmountString(amountStr) {
  // Remove all commas (thousand separators), keep period as decimal
  const cleaned = amountStr.replace(/,/g, "");
  return parseFloat(cleaned);
}

// Test normalizeAmountString function
console.log("🧪 Testing normalizeAmountString()");
console.log("=".repeat(50));

const tests = [
  { input: "1,234.50", expected: 1234.50 },
  { input: "1234.50", expected: 1234.50 },
  { input: "23.50", expected: 23.50 },
  { input: "1,000.00", expected: 1000.00 },
  { input: "10,000.50", expected: 10000.50 },
];

let passed = 0;
let failed = 0;

tests.forEach((test, index) => {
  const result = normalizeAmountString(test.input);
  const success = Math.abs(result - test.expected) < 0.01;
  
  if (success) {
    console.log(`✅ Test ${index + 1}: "${test.input}" → ${result} (Expected: ${test.expected})`);
    passed++;
  } else {
    console.log(`❌ Test ${index + 1}: "${test.input}" → ${result} (Expected: ${test.expected})`);
    failed++;
  }
});

console.log("=".repeat(50));
console.log(`📊 Results: ${passed} passed, ${failed} failed`);

// Test regex patterns
console.log("\n🧪 Testing Regex Patterns");
console.log("=".repeat(50));

const regexPattern = /(\d{1,3}(?:[.,]\d{3})*[.,]\d{2,4}|\d+[.,]\d{2,4})/g;

const regexTests = [
  { text: "TOTAL RM 1,234.50", shouldMatch: true, expected: "1,234.50" },
  { text: "TOTAL 23.50", shouldMatch: true, expected: "23.50" },
  { text: "NET TOTAL 1,000.00", shouldMatch: true, expected: "1,000.00" },
  { text: "JUMLAH 45.50", shouldMatch: true, expected: "45.50" },
  { text: "No amount here", shouldMatch: false },
];

let regexPassed = 0;
let regexFailed = 0;

regexTests.forEach((test, index) => {
  const matches = test.text.match(regexPattern);
  const hasMatch = matches !== null;
  
  if (test.shouldMatch) {
    if (hasMatch && matches[0] === test.expected) {
      console.log(`✅ Test ${index + 1}: "${test.text}" → Matched "${matches[0]}"`);
      regexPassed++;
    } else {
      console.log(`❌ Test ${index + 1}: "${test.text}" → Expected "${test.expected}", got ${hasMatch ? matches[0] : "no match"}`);
      regexFailed++;
    }
  } else {
    if (!hasMatch) {
      console.log(`✅ Test ${index + 1}: "${test.text}" → No match (correct)`);
      regexPassed++;
    } else {
      console.log(`❌ Test ${index + 1}: "${test.text}" → Unexpected match "${matches[0]}"`);
      regexFailed++;
    }
  }
});

console.log("=".repeat(50));
console.log(`📊 Results: ${regexPassed} passed, ${regexFailed} failed`);

// Test confidence calculation
console.log("\n🧪 Testing Confidence Calculation");
console.log("=".repeat(50));

const confidenceTests = [
  { source: "net", expected: 0.95 },
  { source: "total", expected: 0.95 },
  { source: "jumlah", expected: 0.8 },
  { source: "subtotal", expected: 0.8 },
  { source: "fallback", expected: 0.6 },
  { source: null, expected: 0.0 },
];

let confidencePassed = 0;
let confidenceFailed = 0;

confidenceTests.forEach((test, index) => {
  let confidence = 0.0;
  
  if (test.source === "net" || test.source === "total") {
    confidence = 0.95;
  } else if (test.source === "jumlah" || test.source === "subtotal") {
    confidence = 0.8;
  } else if (test.source === "fallback") {
    confidence = 0.6;
  } else {
    confidence = 0.0;
  }
  
  const success = confidence === test.expected;
  
  if (success) {
    console.log(`✅ Test ${index + 1}: source="${test.source}" → confidence=${confidence}`);
    confidencePassed++;
  } else {
    console.log(`❌ Test ${index + 1}: source="${test.source}" → confidence=${confidence} (Expected: ${test.expected})`);
    confidenceFailed++;
  }
});

console.log("=".repeat(50));
console.log(`📊 Results: ${confidencePassed} passed, ${confidenceFailed} failed`);

// Final summary
console.log("\n" + "=".repeat(50));
console.log("📊 FINAL SUMMARY");
console.log("=".repeat(50));
console.log(`Normalize Function: ${passed}/${tests.length} passed`);
console.log(`Regex Patterns: ${regexPassed}/${regexTests.length} passed`);
console.log(`Confidence Calculation: ${confidencePassed}/${confidenceTests.length} passed`);
console.log(`\nOverall: ${passed + regexPassed + confidencePassed}/${tests.length + regexTests.length + confidenceTests.length} tests passed`);

if (passed + regexPassed + confidencePassed === tests.length + regexTests.length + confidenceTests.length) {
  console.log("\n✅ ALL TESTS PASSED!");
} else {
  console.log("\n❌ SOME TESTS FAILED - Please review");
}

