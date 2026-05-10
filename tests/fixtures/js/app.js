// Clean JavaScript fixture — used by CI integration tests (sast-javascript.yml)
// Must remain vulnerability-free so the SAST job passes with exit-code: 1

export const add = (a, b) => a + b;

export const greet = (name) => `Hello, ${name}!`;
