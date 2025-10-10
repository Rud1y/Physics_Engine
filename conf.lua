local love = require "love"

function love.conf(app)
    app.window.fullscreen = true
    app.window.fullscreentype = "desktop"
    app.window.width = 1280
    app.window.height = 720
    app.window.resizable = true
    app.window.title = "Physics Engine"
end