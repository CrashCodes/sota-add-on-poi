
const path = require('path');
const { src, dest, watch, series, parallel } = require('gulp');
const zip = require('gulp-zip');
const changed = require('gulp-changed');
const print = require('gulp-print').default;
const package = require('./package.json');
const fs = require('fs');
const fsPromises = fs.promises;


const sourceBase = 'lua';
const sourceGlobs = ['lua/**'];

// This will need to change for Mac, Linux, or non-standard directory structure.
const sotaLuaFolder = (process.platform === "win32" && process.env.APPDATA) 
    ? path.join(process.env.APPDATA, 'Portalarium\\Shroud of the Avatar\\Lua') 
    : '';

console.log('sotaLuaFolder=' + sotaLuaFolder);


// TODO: make this deal with deleting files
// TODO: make this deal with creating empty sub-directories
async function sync() {
    return src(sourceGlobs, {base: sourceBase})
        .pipe(changed(sotaLuaFolder))
        .pipe(print())
        .pipe(dest(sotaLuaFolder));
}


async function dev() {    
    watch(sourceGlobs, {ignoreInitial: false}, sync);
}

async function clean() {

    // the recursive option is experimental see: https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fspromises_rmdir_path_options
    return await fsPromises.rmdir('dist', {recursive: true});
}

async function makeDistDir() {
    return await fsPromises.mkdir('dist', {recursive: true}); // using recursive:true to keep from failing if already exists.
}


async function zipLua() {
    const zipFilename = process.env.BUILD_NUMBER 
        ? `crashcodes.poi-${package.version}+${process.env.BUILD_NUMBER}.zip`
        : `crashcodes.poi-${package.version}.zip`;
    
	return src(sourceGlobs, {base: sourceBase})
		.pipe(zip(zipFilename))
		.pipe(dest('dist'));
}


// see: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=azure-devops
async function ymlForAzure() {
    const data = `variables:\n  version: '${package.version}'\n  buildNumber: '${process.env.BUILD_NUMBER || ""}'`;
    return await fsPromises.writeFile('dist/variables.yml', data);
}

// see: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#set-variables-in-scripts
async function bashScriptForAzure() {
    const data = `echo "##vso[task.setvariable variable=version]${package.version}"\n`
        + `echo "##vso[task.setvariable variable=bn]${process.env.BUILD_NUMBER || ""}"\n`; // using a variable "buildNumber" will fail silently
    return await fsPromises.writeFile('dist/variables.sh', data);
}


const build = series(makeDistDir, parallel(zipLua, bashScriptForAzure));

exports.dev = dev;
exports.build = build;
exports.clean = clean;
exports.rebuild = series(clean, build);
exports.default = exports.rebuild;


// node_modules/gulp/node_modules/gulp-cli/lib/versioned/^4.0.0/index.js:36:18
// env.configPath <-- is undefined
// function execute(opts, env, config)
// internal/modules/cjs/helpers.js:77:18
// internal modules can be seen here: https://github.com/nodejs/node/tree/v12.x/lib/internal/modules

