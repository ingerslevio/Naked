fs = require 'fs'  
wrench = require 'wrench'

build = require('consolidate-build')
path = require('path')
_ = require('underscore')

actions = []
# actions = [] for actionPath in fs.readdirSync fs.realpathSync(path.join(__dirname, 'actions'))
#   require("./actions/#{actionPath}")(grunt)

  
#   #fs = require 'fs'
#   #wrench = require 'wrench'


actions.push

  initialize: (context) ->
    context.data.tryClearCount = 0

  beforeBuild: (context) ->
    do tryClear = =>
      if context.data.tryClearCount >= 1000
        throw 'Could not clear old directory (#{context.destinationPath}).'
        return
      if context.clear and fs.existsSync context.destinationPath
        try
          wrench.rmdirSyncRecursive(context.destinationPath, yes)
          log.debug "Cleared old content (#{context.destinationPath})" 
          context.next()
        catch e
          log.debug "Got an error trying to delete old dir (#{context.destinationPath}). Trying again, attempt #{context.data.tryClearCount}. (Error: #{error: e}"
          context.data.tryClearCount++
          setTimeout tryClear, 10
      else
        context.next()

#   beforeBuildFile: (context) ->

actions.push

  #path = require 'path'
  #fs = require 'fs'

  initialize: (context) ->
    if context.data.listFileName
      context.data.outFiles = []

  completedFile: (context) ->
    if context.data.listFileName
      context.data.outFiles.push context.file

  completedBuild: (context) ->
    if context.data.listFileName
      outFiles = for file in context.data.outFiles
        path.relative(context.destinationPath,file).replace(/\\/g, "\/")
      listFile = "#{context.destinationPath}/#{context.listFileName}"
      fs.writeFileSync listFile, "#{context.data.list.set} = ['#{outFiles.join('\',\'')}']", "utf-8"
      log.debug 'Written list file: ' + listFile

log =
  debug: (message) ->
    console.log message

callActions = (context, method) =>
  for action in actions
    action[method]?.apply(@, [context])

addStepsForActions = (context, method) =>
  for action in actions when action[method]?
    do (action) =>
      context.steps.push (context2) =>
        action[method](context2)

 
runOnFiles = (context) ->
  filesDone = 0

  context.data = {}
  context.steps = []

  callActions context, 'initialize'

  addStepsForActions context, 'beforeBuild'

  for file in context.files    

    do (file) =>
      context.steps.push (context) =>
        extension = path.extname(file).substring(1)
        builder = _.find(build, (x) -> x.inExtension is extension)

        inExtension = builder?.inExtension ? extension
        outExtension = builder?.outExtension ? extension
        outFile = path.join context.destinationPath, path.relative(context.sourcePath, file[0...file.length-inExtension.length] + outExtension)

        directory = path.dirname(outFile)

        try
          wrench.mkdirSyncRecursive(directory, '0o0777')
          log.debug "Created #{directory}"
        catch e
          throw "Got an error trying to create destination #{directory} (Error: #{e})"
        
        if not fs.existsSync(file)
          fs.unlink outFile, (err) ->
            throw err if err
            context.next()
        else if builder
          builderOptions = context.data[inExtension] ? {}
          builder file, builderOptions, (err, output) ->
            writeContent = if err
              console.log "Error in #{file}", err
              "alert(\"#{file}\\n#{err}\");"
            else
              output

            fs.writeFile outFile, writeContent, ->
              log.debug "Created #{outFile}"
              context.file = outFile
              callActions context, 'completedFile'
              context.next()
        else
          inStr = fs.createReadStream(file)
          outStr = fs.createWriteStream(outFile)
          inStr.pipe(outStr)
          log.debug "Created #{outFile}"
          context.file = outFile
          callActions context, 'completedFile'
          context.next()

  context.steps.push (context) =>
    callActions context, 'completedBuild'
    context.next()

  context.next = =>
    if context.steps.length
      step = context.steps.shift()
      step(context)

  context.next()

getArg = (name) -> 
  _.find(process.argv, (x) -> x[0..name.length].toLowerCase() is name + "=")?.replace(/[^=]+=/i,'')

runOnFiles 
  files: getArg("files").split(/;/)
  destinationPath: getArg("destination")
  sourcePath: getArg("source")
  clear: getArg("clear")?.toLowerCase() in ['true', '1', 'on']

