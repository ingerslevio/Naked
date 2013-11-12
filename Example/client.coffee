path = require 'path'
root = path.relative path.join __dirname, '..', 'Ennova.BuildScript.ExampleProject', 'Client'

module.exports = 
    build: 
      development: 
        clear: yes
        src: [
          path.join root, '/src/*.*'
        ]
        srcRoot: path.join root, '/src'
        dest: path.join root, '/build'
        eco:
          autoReload: yes
          webApiUrl: '/requests'

    test:
      source:
        root:
          path.join root, '/build'
      # qualityAssurance:
      #   clear: yes
      #   src: [
      #     'src/app/**/*.*'
      #     'src/dep/**/*.*'
      #     'src/images/**/*.png'
      #     'src/images/**/*.jpg'
      #     'src/images/**/*.gif'
      #     'src/**/*.swf'
      #     'src/styles/style.styl'
      #     'src/require.coffee'
      #     'src/Index.eco'
      #   ]
      #   srcRoot: 'src'
      #   dest: 'build-qualityassurance'
      #   eco:
      #     webApiUrl: '/requests'
      # publictest:
      #   clear: yes
      #   src: [
      #     'src/app/**/*.*'
      #     'src/dep/**/*.*'
      #     'src/images/**/*.png'
      #     'src/images/**/*.jpg'
      #     'src/images/**/*.gif'
      #     'src/**/*.swf'
      #     'src/styles/style.styl'
      #     'src/require.coffee'
      #     'src/Index.eco'
      #   ]
      #   srcRoot: 'src'
      #   dest: 'build-publictest'
      #   eco:
      #     webApiUrl: '/requests'
      # production:
      #   clear: yes
      #   src: [
      #     'src/app/**/*.*'
      #     'src/dep/**/*.*'
      #     'src/images/**/*.png'
      #     'src/images/**/*.jpg'
      #     'src/images/**/*.gif'
      #     'src/**/*.swf'
      #     'src/styles/style.styl'
      #     'src/require.coffee'
      #     'src/Index.eco'
      #   ]
      #   srcRoot: 'src'
      #   dest: 'build-production'
      #   eco:
      #     webApiUrl: '/requests'

    # reload: 
    #   port: 6001
    #   proxy:
    #     host: 'localhost'
 
    # watch: 
    #   files: ['src/**/*']
    #   tasks: 'build:development reload'