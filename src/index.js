const { getOptions } = require('loader-utils');
const PegImportHelper = require('./pegImportHelper');

module.exports = function (source, map) {
  const rootPath = this.resourcePath;
  const options = getOptions(this);
  options.output = 'source';

  const pegHelper = new PegImportHelper(this);
  
  return pegHelper.generateParser(rootPath, options);
};