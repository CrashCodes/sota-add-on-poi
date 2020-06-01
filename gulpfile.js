
const path = require('path');
const { src, dest, watch } = require('gulp');
const changed = require('gulp-changed');
const print = require('gulp-print').default;

const sourceBase = 'lua';
const sourceGlobs = ['lua/**'];
// const sourceGlobs = ['lua/crashcodes.poi.lua'];
const destFolder = path.join(process.env.APPDATA, 'Portalarium\\Shroud of the Avatar\\Lua'); // This will need to change for Mac, Linux, or non-standard directory structure.
console.log('destFolder=' + destFolder);
// TODO: make this deal with deleting files
// TODO: make this deal with creating empty sub-directories

async function sync() {
    return src(sourceGlobs, {base: sourceBase})
        .pipe(changed(destFolder))
        .pipe(print())
        .pipe(dest(destFolder));
}


async function defaultTask() {
    watch(sourceGlobs, {ignoreInitial: false}, sync);
}


exports.default = defaultTask