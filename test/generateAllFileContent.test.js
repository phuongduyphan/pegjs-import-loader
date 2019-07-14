import path from 'path';
import fs from 'fs';
import PegImportHelper from '../src/pegImportHelper';

test('Generate all file content test', async () => {
  const pegHelper = new PegImportHelper();
  const output = pegHelper.generateAllFileContent(path.resolve(__dirname, 'mock/mysql/parser.pegjs'));
  const result = fs.readFileSync(path.resolve(__dirname, 'mock/output.pegjs'), 'utf-8');

  expect(output).toBe(result);
});