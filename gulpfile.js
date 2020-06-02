
const path = require('path');
const { src, dest, watch, series } = require('gulp');
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

async function build() {
	return src(sourceGlobs, {base: sourceBase})
		.pipe(zip('crashcodes.poi-' + package.version + '.zip')) // TODO: add a build number
		.pipe(dest('dist'));
}


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
