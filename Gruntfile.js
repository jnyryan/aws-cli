module.exports = function(grunt) {
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    coffee:{
    	compile:{
				options: {
		      bare: true
		    },
		    files: {
		      'bin/aws':'coffee/bin/aws.coffee'
		    }
		  }
		},
    watch: {
      files: ['coffee/bin/aws.coffee'],
      tasks: ['coffee']
    }
  });
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.registerTask('default', ['coffee','watch']);
};