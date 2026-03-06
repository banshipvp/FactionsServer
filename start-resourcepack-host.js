const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, 'resourcepacks');
const port = 8080;

const mime = (file) => {
  if (file.endsWith('.zip')) return 'application/zip';
  if (file.endsWith('.png')) return 'image/png';
  if (file.endsWith('.json')) return 'application/json';
  if (file.endsWith('.mcmeta')) return 'application/json';
  return 'application/octet-stream';
};

http.createServer((req, res) => {
  const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
  const requested = urlPath === '/' ? '/SimpleShopGUI.zip' : urlPath;
  const safePath = path.normalize(requested).replace(/^([.][.][/\\])+/, '');
  const filePath = path.join(root, safePath.replace(/^[/\\]/, ''));

  if (!filePath.startsWith(root)) {
    res.statusCode = 403;
    res.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.statusCode = 404;
      res.end('Not found');
      return;
    }
    res.setHeader('Content-Type', mime(filePath));
    res.end(data);
  });
}).listen(port, () => {
  console.log(`Resource pack host running on http://0.0.0.0:${port}/`);
  console.log(`Serving files from: ${root}`);
});
