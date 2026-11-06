fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

name 'rsblood-progressbar'
author 'William Brito — RealitySucksRP'
description 'Framework-agnostic zombie/horror progress bar with QBCore, Qbox, ox_lib, ESX, and standalone adapters.'
version '3.2.0'

ui_page 'html/index.html'

client_scripts {
    'lua/config.lua',
    'lua/client.lua',
    'lua/locales/*.lua',
    'lua/provider.lua',
}

server_scripts {
    'lua/server.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/themes.css',
    'html/script.js',
    'html/vue.global.prod.js',
}

-- Replacement aliases for resources that depend on the standard QBCore or ESX
-- progress-bar names. Do not run the original providers at the same time.
provide 'progressbar'
provide 'esx_progressbar'
