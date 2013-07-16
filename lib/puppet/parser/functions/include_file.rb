
module Puppet::Parser::Functions
    newfunction(:include_file, :type => :statement, :doc => <<-END

"Include" the contents of another file at the point where this function is
called.

*Description:*

    This function essentially provides the include functionality of other
    languages. Given the path to a file (either absolute or relative to
    the current file), it "virtually" adds that file's contents to the
    current file at the point the function is called.

    This is different from puppet's built-in include, import, and require
    functionality. It's much more "raw" in a sense, but that's what makes it
    useful, especially as your site manifest begins to get large and unweildy
    and your environment gets too complicated to neatly stuff into a strict
    hierarchy of namespaces and such.

    This function can be particularly useful in places where you might want
    multiple inheritance, or when you can't use inheritance, or you don't *want*
    to use inheritance, or any tim you need to reuse some "snippet" of puppet
    manifest code in multiple places, perhaps across different namespaces and
    it simply doesn't belong in the top-level namespace.

    Bottom line is, I wanted this functionality, didn't find it anywhere else,
    and so created it as part of this module so that others can use it if they
    wish. :)

*Required Parameters:*

    * The path to the file whose contents will be "included". This path can
      either be absolute or relative to the file in which the function is
      being called.

*Optional Parameters:*

    None.

*Returns:*

    Nothing - this is a "statement" function which is called for its
    side-effects.

*Errors:*

    An exception will be raised if:
      * The file can not be found or is empty
      * The file can not be parsed

*Compatibility:*

    This function is currently known to work in the following environments:
      * Puppet 2.6.17 with Ruby 1.8.7 on CentOS 6.3
      * Puppet 2.6.18 with Ruby 1.8.5 on CentOS 5.9
      * Puppet 2.7.18 with Ruby 1.9.3 on Ubuntu 13.04

    This section will be updated as this function gets tested in additional
    environments. If an incompatibility is found it will be listed below if
    it can not be fixed or worked-around.

*Caveats:*

    This function cracks open the parser class to get access to its internal
    parsing function, which is *supposed* to be private. (It does this to get
    at the AST object returned after the actual parse is done) However, because
    messing with such things is usually just *asking* for trouble, this module
    may not work on versions of puppet other than the ones it has been
    successfully tested on (listed above)

    If you create a "cycle" in your includes, you're going to have a Bad Time™.
    Currently, no recursion detection is done AT ALL. This may be fixed in a
    future version if it becomes an actual problem.

*Example:*

    ### in file inc/metavars.pp
    $metavars = [ "foo", "bar", "baz", "quux", "wibble", "wobble" ]


    ### in file some/resource.pp
    define some::resource {

        include_file( "../inc/metavars.pp" )

        if member( $metavars, $name ) { meta::resource { $name: } }
        else { other::resource { $name: } }
    }

END
    ) do |args|
        # unpack the arg array
        inc_file = args[0]

        # get some info about the caller
        cur_file = self.source.file
        cur_line = self.source.line
        cur_dir  = File.dirname( cur_file )
        env      = self.environment

        # if the file to include is not an absolute path, then it's
        # relative to the caller
        inc_file_abs_path = inc_file[0..0] == "/" ? inc_file \
                          : cur_dir + "/" + inc_file

        # note: debating between logging this at info or debug level
        Puppet.debug("inserting '#{inc_file}' into '#{cur_file}' at line #{cur_line}")

        # set up a parser, parse the file, then add the resulting AST to the
        # caller's scope by having it evaluate itself with "self" which is
        # conveniently already a Puppet::Parser::Scope object.
        Puppet.debug("parsing '#{inc_file}'")
        par = Puppet::Parser::Parser.new( env )
        ast = par.yyparse_file( inc_file_abs_path )
        Puppet.debug("evaluating the ast from '#{inc_file}'")
        res = ast.evaluate( self )
        Puppet.debug("done inserting '#{inc_file}' into '#{cur_file}' at line #{cur_line}")
    end
end


# crack open the parser class to add this public method
# that wraps the private yyparse method, so we can parse
# the file that is to be included without puppet interfering.
require 'puppet/parser'
class Puppet::Parser::Parser
    module_eval <<'END'
    def yyparse_file( file )
        fstr = IO::read( file )
        @lexer.string = fstr
        return yyparse(@lexer, :scan)
    end
END
end


# vi: set ts=4 sw=4 et :
