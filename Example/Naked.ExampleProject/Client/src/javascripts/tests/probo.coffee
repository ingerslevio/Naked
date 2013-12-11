
window.probo =

  initialize: (config) ->
    @preloadedModules = {}
    @extensions = {}

    config.preloadModules ?= []
    config.extensions ?= []

    requireConfigs = if typeof config.requireConfig is 'string' then [config.requireConfig] else config.requireConfig ? []
    @requireConfig = @mergeConfigs {}, requireConfigs...

    require (config.preloadModules).concat(config.extensions), (modules...) =>
      for modulePath, moduleIndex in config.preloadModules
        @preloadedModules[modulePath] = modules[moduleIndex]
      for modulePath, moduleIndex in config.extensions
        @extensions[modulePath] = modules[config.preloadModules.length + moduleIndex]

      @callExtensions 'initialize', @

      if window.jasmine?
        @initializeJasmine(config)

      config.ready?()

  setupTest: (configFunc) ->
    @uniqueFactoryCounter ?= 1
    @uniqueTestContextCounter ?= 1
    factoryName = "Factory#{@uniqueFactoryCounter++}"

    contextFactory = (callback) =>
      # generates a test context per test

      config = configFunc()

      map = {}

      # create a new map which will override the path to a given dependencies
      # so if we have a module in 'm1', requiresjs will look now under 'stub_m1'
      requireMap = {}

      # generate a context for the test
      testContext =
        # save all maps for easy lookup
        map: {}
        isDone: no
        requireContextName: "TestContext#{@uniqueTestContextCounter++}"
        # a list of instances created by the test
        instances: {}

      # additional things to require before running test
      additionalRequires = {}

      helpers = 
        map: (from, to) ->
          map[from] = to

      @callExtensions 'setup', helpers, testContext

      # call the config with the setup helpers
      config.map?.apply helpers

      # create new definitions that will return our passed stubs or mocks
      for key, value of map
        if typeof value is 'string'
          requireMap[key] = value
          additionalRequires[key] = value
        else
          stubname = 'stub_' + key
          requireMap[key] = stubname
          do (value) ->
            define stubname, ->
              value
            testContext.map[key] = value

      # Map and defined preloaded modules for load only once and use forever behavior
      for preloadedModulePath, preloadedModule of @preloadedModules
        do (preloadedModulePath, preloadedModule) ->
          preloadedModuleName = 'preloaded_' + preloadedModulePath
          requireMap[preloadedModulePath] = preloadedModuleName
          define preloadedModuleName, -> preloadedModule

      # create a new requireContext with the new dependency paths
      testContext.require = requireContext = require.config
        context: testContext.requireContextName
        baseUrl: @requireConfig.baseUrl ? ''
        shim: @requireConfig.shim
        paths: @requireConfig.paths
        packages: @requireConfig.packages
        urlArgs: @requireConfig.urlArgs
        map:
          "*": requireMap

      subjectModules = []
      subjectNames = []
      for subjectName,subjectModule of config.subject
        subjectNames.push subjectName
        subjectModules.push subjectModule
      for subjectName,subjectModule of additionalRequires
        subjectNames.push subjectName
        subjectModules.push subjectModule

      requireContext subjectModules, (subjectObjects...) ->
        subjects = {}
        for subjectObject, subjectIndex in subjectObjects
          subjects[subjectNames[subjectIndex]] = subjectObject
        callback(subjects, testContext)
        testContext.isDone = yes

      testContext

    contextFactory.factoryName = factoryName
    contextFactory

  setupJasmineTest: (config) ->
    {currentSuite} = jasmine.getEnv()
    currentSuite.testFactory = probo.setupTest ->
      config.apply(jasmine.getEnv().currentSpec)

    beforeEach ->    
      runs ->
        @context = currentSuite.testFactory (subjects, tc) => 
          @subjects = subjects
          for subjectName, subject of subjects
            @[subjectName] ?= subject
          for contextKey, contextValue of @context
            @[contextKey] = contextValue

      waitsFor (-> 
        @context?.isDone ? false
      ), "Loading of requirejs dependencies took to long", 1000

  callExtensions: (step, args...) ->
    for extensionPath, extension of @extensions
      extension[step]?(args...)

  initializeJasmine: (config) ->
    jasmine.WaitsForBlock.TIMEOUT_INCREMENT = 1;

    if config.profile ? no

      if config.profile is yes or config.profile is 'time'
        beforeEach ->
          console.time @description
        afterEach ->
          console.timeEnd @description
      if config.profile is yes
        beforeEach ->
          console.profile @description if config.profile is yes
        afterEach ->
          console.profileEnd @description

    if config.tests?
      config.ready = ->
        require config.tests, ->
          jasmineEnv = jasmine.getEnv()
          jasmineEnv.updateInterval = 1000

          reporterName = 'HtmlReporter'
          for arg in window.document.location.search.substring(1).split('&')
            [prop, value] = arg.split('=')
            if prop is 'reporter'
              reporterName = value
            
          reporter = new jasmine[reporterName]()

          jasmineEnv.addReporter(reporter)
          
          if reporter.specFilter?
            jasmineEnv.specFilter = (spec) ->
              reporter.specFilter(spec)

          currentWindowOnload = window.onload

          window.onload = ->
            if currentWindowOnload
              currentWindowOnload()
            jasmineEnv.execute()

    @callExtensions 'jasmine'

    window.setup = (config) ->
      probo.setupJasmineTest config

  mergeConfigs: (obj, sources...) ->
    for source in sources
      for property,value of source
        if not obj[property]?
          obj[property] = source[property]
        else if typeof obj is 'string'
          obj[property] = source[property]
        else
          @mergeConfigs obj[property], source[property]
    obj