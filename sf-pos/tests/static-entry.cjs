const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const indexHtml = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const devHtml = fs.existsSync(path.join(root, 'dev.html'))
  ? fs.readFileSync(path.join(root, 'dev.html'), 'utf8')
  : '';

if (!indexHtml.includes('./dist/dev.html')) {
  throw new Error('Expected sf-pos/index.html to embed the built dist/dev.html entry for OD preview.');
}

if (indexHtml.includes('/src/main.jsx')) {
  throw new Error('Expected sf-pos/index.html not to depend on the Vite JSX source entry.');
}

if (!devHtml.includes('/src/main.jsx')) {
  throw new Error('Expected sf-pos/dev.html to keep the Vite source entry for future development.');
}
