const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const { createServer } = require('node:net');
const path = require('node:path');
const { after, before, test } = require('node:test');

const appDirectory = path.resolve(__dirname, '..');
const cdsCli = path.join(appDirectory, 'node_modules', '@sap', 'cds-dk', 'bin', 'cds.js');

let serverProcess;
let serviceUrl;

async function findAvailablePort() {
  const server = createServer();
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const { port } = server.address();
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
  return port;
}

async function waitForService(url) {
  const deadline = Date.now() + 30000;
  let lastError;

  while (Date.now() < deadline) {
    if (serverProcess.exitCode !== null) {
      throw new Error(`CAP server exited early with code ${serverProcess.exitCode}`);
    }

    try {
      const response = await fetch(url);
      if (response.ok) return;
      lastError = new Error(`CAP server returned HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }

    await new Promise((resolve) => setTimeout(resolve, 250));
  }

  throw new Error('CAP server did not become ready within 30 seconds', { cause: lastError });
}

before(async () => {
  const port = await findAvailablePort();
  serviceUrl = `http://127.0.0.1:${port}/odata/v4/warehouse`;
  serverProcess = spawn(
    process.execPath,
    [cdsCli, 'serve', '--port', String(port)],
    {
      cwd: appDirectory,
      env: { ...process.env, NODE_ENV: 'test' },
      stdio: 'ignore',
    },
  );
  await waitForService(`${serviceUrl}/GoodsReceipts`);
});

after(async () => {
  if (!serverProcess || serverProcess.exitCode !== null) return;
  serverProcess.kill('SIGTERM');
  await Promise.race([
    once(serverProcess, 'exit'),
    new Promise((resolve) => setTimeout(resolve, 5000)),
  ]);
  if (serverProcess.exitCode === null) {
    serverProcess.kill('SIGKILL');
    await once(serverProcess, 'exit');
  }
});

async function getGoodsReceipts(query = '') {
  const response = await fetch(`${serviceUrl}/GoodsReceipts${query}`);
  const body = await response.text();
  assert.equal(response.status, 200, body);
  return JSON.parse(body);
}

test('GET returns all six seeded goods receipts over OData V4', async () => {
  const payload = await getGoodsReceipts();

  assert.match(payload['@odata.context'], /\$metadata#GoodsReceipts$/);
  assert.equal(payload.value.length, 6);
  assert.equal(payload.value[0].material, 'MAT-100045');
  assert.equal(payload.value[0].warehouse, 'WH-100');
  assert.equal(payload.value[0].quantity, 120);
  assert.equal(payload.value[0].status, 'RECEIVED');
  assert.ok(payload.value[0].ID);
  assert.ok(payload.value[0].receivedAt);
});

test('$filter returns only receipts for the requested warehouse', async () => {
  const query = `?%24filter=${encodeURIComponent("warehouse eq 'WH-100'")}`;
  const payload = await getGoodsReceipts(query);

  assert.equal(payload.value.length, 2);
  assert.ok(payload.value.every((receipt) => receipt.warehouse === 'WH-100'));
});

test('$select limits the returned properties', async () => {
  const query = `?${new URLSearchParams({ $select: 'material,quantity' })}`;
  const payload = await getGoodsReceipts(query);

  assert.equal(payload.value.length, 6);
  assert.deepEqual(Object.keys(payload.value[0]).sort(), ['ID', 'material', 'quantity']);
});

test('$top limits the number of returned receipts', async () => {
  const query = `?${new URLSearchParams({ $top: '2' })}`;
  const payload = await getGoodsReceipts(query);

  assert.equal(payload.value.length, 2);
});

test('POST is rejected because the entity is read-only', async () => {
  const response = await fetch(`${serviceUrl}/GoodsReceipts`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      material: 'MAT-NEW',
      warehouse: 'WH-100',
      quantity: 1,
      unit: 'EA',
      status: 'RECEIVED',
    }),
  });

  assert.ok([405, 501].includes(response.status), `Unexpected write response: ${response.status}`);
});
