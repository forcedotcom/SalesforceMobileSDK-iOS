#!/usr/bin/python
# -*- coding: utf-8 -*-
# ----------------------------------------------------------------------------
# Xcode 4 template generator
#
# Based on the original code by Ricardo Quesada. 
# Modifications & Ugly Hacks by Nicolas Goles D. 
#
# LICENSE: MIT
#
# Generates an Xcode4 template given several input parameters.
#
# Format taken from: http://blog.boreal-kiss.net/2011/03/11/a-minimal-project-template-for-xcode-4/
#
# NOTE: Not everything is automated, and some understanding about the Xcode4 template system
# is still needed to use this script properly (read the link above).
# ----------------------------------------------------------------------------
'''
Xcode 4 template generator
'''

__docformat__ = 'restructuredtext'

#Add here whatever you need before your Node
_template_open_body = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>"""

_template_description = None
_template_identifier = None
_template_concrete = "yes"
_template_ancestors = None
_template_kind = "Xcode.Xcode3.ProjectTemplateUnitKind"
_template_close_body = "\n</dict>\n</plist>"
_template_plist_name = "TemplateInfo.plist"
_template_shared_settings = None

# python imports
import sys
import os
import getopt
import glob
import shutil

class Xcode4Template(object):
    def __init__( self, directories, group = None, in_output_path = None, ignored_files = None):
        self.currentRootDirectory = None
        self.directories = directories #directory list
        self.ignored_files = ignored_files        
        self.files_to_include = []
        self.wildcard = '*'
        self.allowed_extensions = ['h', 'hpp', 'c', 'cpp', 'cc', 'm', 'mm', 'lua', 'png', 'fnt', 'pvr','a','framework',''] # Extensions of files to add to project.
        self.ignore_dir_extensions = ['xcodeproj']
        self.forced_dir_extensions = ['framework']
        self.group = group # fixed group name
        self.group_index = 1 # automatic group name taken from path
        self.output = []
        self.output_path = in_output_path

    def scandirs(self, path, includeAll):       
        for currentFile in glob.glob(os.path.join(path, self.wildcard)):
            if os.path.isdir(currentFile):
                name_extension = currentFile.split('.')
                extension = name_extension[-1]
                         
                if extension in self.forced_dir_extensions and currentFile not in self.ignored_files:
	                self.scandirs(currentFile,True)
                else:
	                if extension not in self.ignore_dir_extensions and currentFile not in self.ignored_files:
						self.scandirs(currentFile, includeAll)
                         
            else:
                self.include_file_to_append(currentFile,includeAll)
   
    #            
    # append file
    #
    def include_file_to_append(self, currentFile, includeAll):
        currentExtension = currentFile.split('.')
        print "currentExtension: '%s'" % currentExtension
		
        if includeAll or currentExtension[-1] in self.allowed_extensions:
            self.files_to_include.append( currentFile )			
    
	
    #
    # Helper method to filter files by absolute path when using shutils.copytree
    #
    def ignore_files(self, directory_entered, directory_contents):
        should_ignore = []
        for file in self.ignored_files:
            for content in directory_contents:
                if os.path.join(os.path.abspath(directory_entered), content) == file:
                    should_ignore.append(content)
        return should_ignore
        
    #
    # Change the Absolute Path to a relative path ( starting from directory that scandirs is using )
    #
    def change_path_to_relative( self, absolute_path ): 
        return os.path.relpath( absolute_path, os.path.split( os.path.relpath(self.currentRootDirectory) )[0])
    
    #
    # append the definitions
    #
    def append_definition( self, output_body, path, group ):
        output_body.append("\n\t\t<key>%s</key>" % self.change_path_to_relative(path) )
        output_body.append("\t\t<dict>")
        
        #Fix the absolute path so that the Xcode Groups created for the .xctemplate directory are relative.
        path =  self.change_path_to_relative(path)      
        groups = path.split('/')        
        output_body.append("\t\t\t<key>Group</key>\t\t\t")
        output_body.append("\t\t\t<array>")
    
        for group in groups[:(len(groups)-1)]:
            output_body.append("\t\t\t\t<string>%s</string>" % group)

        output_body.append("\t\t\t</array>")
        output_body.append("\t\t\t<key>Path</key>\n\t\t\t<string>%s</string>" % path )
        output_body.append("\t\t</dict>")

    #
    # Generate the "Definitions" section
    #
    def generate_definitions( self ):   
        output_banner = "\n\n\t<!-- Definitions section -->"
        output_header = "\n\t<key>Definitions</key>"
        output_dict_open = "\n\t<dict>"
        output_dict_close = "\n\t</dict>"

        output_body = []
        for path in self.files_to_include:

            # group name
            group = None
            if self.group is not None:
                group = self.group
            else:
                # obtain group name from directory
                dirs = os.path.dirname(path)
                subdirs = dirs.split('/')
                if self.group_index < len(subdirs):
                    group = subdirs[self.group_index]
                else:
                    # error
                    group = None

            # get the extension
            filename = os.path.basename(path)
            name_extension= filename.split('.')
            extension = None
            if len(name_extension) == 2:
                extension = name_extension[1]
            
            self.append_definition( output_body, path, group )

        self.output.append( output_banner )
        self.output.append( output_header )
        self.output.append( output_dict_open )
        self.output.append( "\n".join( output_body ) )
        self.output.append( output_dict_close )

    # 
    # Generates the "Nodes" section
    #
    def generate_nodes( self ):
        output_banner = "\n\n\t<!-- Nodes section -->"
        output_header = "\n\t<key>Nodes</key>"
        output_open = "\n\t<array>\n"
        output_close = "\n\t</array>"

        output_body = []
        for path in self.files_to_include:
            output_body.append("\t\t<string>%s</string>" % self.change_path_to_relative(path) )

        self.output.append( output_banner )
        self.output.append( output_header )
        self.output.append( output_open )
        self.output.append( "\n".join( output_body ) )
        self.output.append( output_close )
      
    #
    #   Format the output .plist string
    #
    def format_xml( self ):
        self.output.append( _template_open_body )
        
        if _template_description or _template_identifier or _template_kind:
            self.output.append ("\n\t<!--Header Section-->")
        
        if _template_description != None:
            self.output.append( "\n\t<key>Description</key>\n\t<string>%s</string>" % _template_description )

        if _template_identifier:
            self.output.append( "\n\t<key>Identifier</key>\n\t<string>%s</string>" % _template_identifier )
        
        self.output.append( "\n\t<key>Concrete</key>")
        
        if _template_concrete.lower() == "yes":
            self.output.append( "\n\t<string>True</string>" )
        elif _template_concrete.lower() == "no":
            self.output.append( "\n\t<string>False</string>" )
        
        self.output.append( ("\n\t<key>Kind</key>\n\t<string>%s</string>" % _template_kind) )
        
        if _template_ancestors:
            self.output.append("\n\t<key>Ancestors</key>\n\t<array>")
            ancestors = _template_ancestors.split(" ")
            for ancestor in ancestors:
                self.output.append("\n\t\t<string>%s</string>" % str(ancestor))
            self.output.append("\n\t</array>")

        if _template_shared_settings:
                self.output.append("\n\t<key>Project</key>")
                self.output.append("\n\t<array>\n\t\t<dict>")
                self.output.append("\n\t\t\t<key>SharedSettings</key>")
                self.output.append("\n\t\t\t<dict>")
                
                shared_settings = _template_shared_settings.split(" ")
                
                if len(shared_settings) % 2 != 0:
                    print "Shared Settings parameters should be an even number (use '*' if only key is needed)"
                    sys.exit(-1)
                
                for i in range( len(shared_settings) - 1 ) :
                    
                    if( str(shared_settings[i]) != "*"):                
                        self.output.append("\n\t\t\t\t<key>%s</key>" % str(shared_settings[i]))
                        
                        if (shared_settings[i+1] == "*"):
                            self.output.append("\n\t\t\t\t<string></string>")
                        else:
                            self.output.append("\n\t\t\t\t<string>%s</string>" % str(shared_settings[i+1]))
                            
                self.output.append("\n\t\t\t</dict>\n\t\t</dict>\n\t</array>")
    
        self.generate_definitions()
        self.generate_nodes()
        self.output.append( _template_close_body )
    
    #
    #   Create "TemplateInfo.plist" file.
    #
    def write_xml( self ):
        FILE = open( _template_plist_name, "w" )
        FILE.writelines( self.output )
        FILE.close()
        
    #
    #   Generates the template directory.
    #
    def pack_template_dir ( self, full_output_path ):
        if full_output_path is None:
            full_output_path = os.path.abspath("./UntitledTemplate")
            
        (template_path, template_name) = os.path.split( os.path.normpath(full_output_path) )

        for directory in self.directories:
            (_, base_dir) = os.path.split(directory)
        
            if(os.path.splitext(template_name)[1] != ".xctemplate"):
                full_output_path = os.path.join(template_path, template_name + ".xctemplate")
            
            target_dir = os.path.normpath(full_output_path) + "/" + base_dir
            shutil.copytree(directory,
                            target_dir,
                            ignore = self.ignore_files)
                            
        shutil.move("TemplateInfo.plist", os.path.normpath(full_output_path))
    
    #
    #   Scan Dirs, format & write.
    #
    def generate( self ):
        for aDirectory in self.directories:
            self.currentRootDirectory = aDirectory
            self.scandirs(aDirectory,False)
                                    
        self.format_xml()
        self.write_xml()

def help():
    print "%s v1.1 - Xcode 4 Template Generator v1.1" % sys.argv[0]
    print "Usage:"
    print "\t-c concrete (concrete or \"abstract\" Xcode template)" 
    print "\t-d one or more space separated directories (e.g -d \"box2d/ someLib/ someOtherLib/\")"
    print "\t-g group (group name for Xcode template)"
    print "\t-o output (output path)"
    print "\t--description \"Xcode Template description\""
    print "\t--identifier (string to identify this template)"
    print "\t--ancestors (string separated by spaces containing all ancestor ids)"
    print "\t--settings Specify build settings for the project (experimental)"
    print "\t--ignore_files Specify a space separated list of files to ignore (e.g \"ignore/a/dir ignore/some/file.txt\")"
    print "\nExample:"
    print "\t%s -d cocos2d --description \"This is my template\" -i com.yoursite.template --ancestors com.yoursite.ancestor1 -c no --settings \"GCC_THUMB_SUPPORT[arch=armv6] *\" " % sys.argv[0]
    sys.exit(-1)

if __name__ == "__main__":
    if len( sys.argv ) == 1:
        help()

    directories = []
    ignored_files = []
    group = None
    output = None
    
    argv = sys.argv[1:]
    try:                                
        opts, args = getopt.getopt(argv, "d:g:i:a:c:o:", ["directories=","group=", "identifier=", "ancestors=", "concrete=", "output=", "settings=", "description=", "ignore_files="])
        for opt, arg in opts:
            
            if opt in ("-d","--directory"):
                for directory in arg.split(" "):
                    directory = os.path.abspath(directory.strip('/'))
                    directories.append(directory)
                    
            elif opt in ("-g","--group"):
                group = arg
            
            elif opt in ("-o", "--output"):
                output = arg        
            
            elif opt in ("--description"):
                _template_description = arg
            
            elif opt in ("--identifier"):
                _template_identifier = arg
            
            elif opt in ("--ancestors"):
                _template_ancestors = arg
            
            elif opt in ("-c", "--concrete"):
                _template_concrete = arg
            
            elif opt in ("-s", "--settings"):
                _template_shared_settings = arg
            
            elif opt in ("--ignore_files"):
                for directory in arg.split(" "):
                    directory = os.path.abspath(directory.strip('/'))
                    ignored_files.append(directory)
                
    except getopt.GetoptError,e:
        print e

    if directory == None:
        help()

    gen = Xcode4Template(directories, group, output, ignored_files)
    gen.generate()
    gen.pack_template_dir(output)
