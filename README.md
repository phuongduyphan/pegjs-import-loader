[![npm version](https://img.shields.io/npm/v/pegjs-import-loader.svg)](https://www.npmjs.com/package/pegjs-import-loader)
![npm license](https://img.shields.io/npm/l/pegjs-import-loader.svg)  
# [PEG.js](https://github.com/pegjs/pegjs) import loader for [webpack](http://webpack.github.io/)
A simple loader for PEG.js that supports importing multiple grammars from different PEG.js files
## Install
`npm install --save-dev pegjs-import-loader pegjs webpack`
## Setup
### Apply via webpack config
*webpack.config.js:*
``` js
module.exports = {
  ...
  module: {
    loaders: [
      {
        test: /\.pegjs$/,
        loader: 'pegjs-import-loader',
        options: { 
            ...
        }
      }
    ]
  }
};
```
### PEG.js options
You can pass options to PEG.js through options property in webpack config. [See more about PEG.js options](https://pegjs.org/documentation)
## Usage
### Importing Syntax
*parser.pegjs:*
```js
{
    const str = 'This is just an example string';
    function concat(a, b) {
        return a.concat(b);
    }
}
Expression
  = head:Term tail:(_ ("+" / "-") _ Term)* {
      return tail.reduce(function(result, element) {
        if (element[1] === "+") { return result + element[3]; }
        if (element[1] === "-") { return result - element[3]; }
      }, head);
    }
    
Factor
  = "(" _ expr:Expression _ ")" { return expr; }
  / Integer
 
@import './base-rules.pegjs'
@import './keywords.pegjs'
```
* Import statement **must be after** the initializer block of PEG.js (*initializer is a piece of JavaScript code in curly braces (“{” and “}”) that precedes the first rule*)
* When importing grammars from other files, **all the rules in those files are accessible** in the current context
* All the **JS variables and functions in initializers will also be accessible** from the current context
* Due to the accessibility of all the rules, variables and functions from other pegjs files in current context, users must be aware of duplication of rule, variable and function names
* **Import files in one-way flow** to avoid circular dependencies

### Generate a parser in JS code
```js
const parser = require('./parser.pegjs');
const result = parser.parse(content);
```
## License
MIT (https://opensource.org/licenses/mit-license.php)
