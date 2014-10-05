class DME
	def initialize(fname)
		@predict = {}
		@premaps = []
		@preskins = []

		@predata = preproc(fname)
		@predata.gsub!(/^\s*$/, "")
		@predata.gsub!(/\n\n(\n+)/m, "\n\n")

		outfname = fname.sub(/\.[^.]*$/, "")
		outfname += ".outdm"
		if outfname == fname then
			outfname += ".outdm"
		end

		puts "Name: #{outfname}"
		fp = File.open(outfname, "wb")
		fp.write(@predata)
		fp.close()
	end

	def parse_expr_starting(expr, start)
		# Strip whitespace
		expr.gsub!(/^\s*/, "")
		expr.gsub!(/\s*$/, "")

		# Follow the chain
		if expr == "" then
			start
		elsif expr[/^(==|!=)(.*)$/] then
			[$1, start, parse_expr($2)]
		elsif expr[/^([*\/%])(.*)$/] then
			[$1, start, parse_expr($2)]
		elsif expr[/^([-+])(.*)$/] then
			[$1, start, parse_expr($2)]
		else
			throw Exception.new("unhandled expression {#{expr}}")
		end
	end

	def parse_expr_list(expr)
		# Strip whitespace
		expr.gsub!(/^\s*/, "")
		expr.gsub!(/\s*$/, "")

		# If nothing, return empty list
		if expr == "" then
			return []
		end

		# Return a map
		expr.split(/\s*,\s*/).map do |v|
			parse_expr(v)
		end
	end

	def parse_expr(expr)
		# Strip whitespace
		expr.gsub!(/^\s*/, "")
		expr.gsub!(/\s*$/, "")

		# Follow the chain
		if expr[/^\((.+?)\)(.*)$/] then
			parse_expr_starting($2, parse_expr($1))
		elsif expr[/^(.+?)(==|!=)(.*)$/] then
			[$2, parse_expr($1), parse_expr($3)]
		elsif expr[/^(.+?)([*\/%])(.*)$/] then
			[$2, parse_expr($1), parse_expr($3)]
		elsif expr[/^(.+?)([-+])(.*)$/] then
			[$2, parse_expr($1), parse_expr($3)]
		elsif expr[/^([!])(.+)$/] then
			[$1, parse_expr($2)]
		elsif expr[/^([a-zA-Z_][0-9a-zA-Z_]*)\s*\((.*?)\)$/] then
			["call", $1, parse_expr_list($2)]
		elsif expr[/^([a-zA-Z_][0-9a-zA-Z_]*)$/] then
			["name", $1]
		elsif expr[/^(-?(0|([1-9][0-9]*)))$/] then
			["int", expr.to_i]
		else
			throw Exception.new("unhandled expression {#{expr}}")
		end
	end

	def run_expr_preproc(expr)
		tag = expr[0]
		case tag
			when "!"
				!run_expr_preproc(expr[1])
			when "call"
				case expr[1]
					when "defined"
						throw Exception.new("invalid tag #{expr}") if expr[2][0][0] != "name"
						@predict.has_key?(expr[2][0][1]) ? 1 : 0
					else
						throw Exception.new("unhandled preproc call {#{expr}}")
				end
			when "name"
				@predict[expr[1]]
			when "int"
				expr[1]
			when "=="
				run_expr_preproc(expr[1]) == run_expr_preproc(expr[2]) ? 1 : 0
			else
				throw Exception.new("unhandled preproc tag {#{expr}}")
		end
	end

	def preproc(fname)
		puts "Preprocessing \"#{fname}\""

		subdir = ""
		subdir = fname[/\//] != nil ? fname.sub(/\/[^\/]*$/, "/"): ""

		# Read data
		data = File.open(fname, "rb").read()

		# Fix newlines
		data.gsub!("\r\n", "\n")
		data.gsub!("\r", "\n")

		# Nuke comments
		data.gsub!(/\/\*(.*?)\*\//m, "")
		data.gsub!(/\/\/.*$/, "")

		# Preprocess code
		kill_list = []
		data.gsub!(/^\s*#\s*(\S*)\s*(.*)$/) do |s|
			cmd = $1
			args = $2
			case cmd
				when "define"
					args[/(\S*)\s*(.*)/]
					name = $1
					expr = $2
					@predict[name] = expr
					#puts "DEFINE {#{name}} {#{expr}}"
					""

				when "undef"
					name = args
					@predict.delete(name)
					#puts "UNDEF {#{name}}"
					""

				when "include"
					args[/"(.*)"/]
					subf = $1
					subf.gsub!(/\\/, "/")
					subf = subdir+subf
					#puts "INCLUDE {#{subf}}"
					if subf[/\.dmm$/i] then
						puts "Adding map #{subf}"
						@premaps.push(subf)
						""
					elsif subf[/\.dmf$/i] then
						puts "Adding skin #{subf}"
						@preskins.push(subf)
						""
					elsif subf[/\.dm$/i] then
						preproc(subdir+subf)
					else
						throw Exception.new("unhandled filetype {#{subf}}")
					end

				when "ifdef"
					expr = parse_expr(args)
					puts "IF {#{expr.to_s}}"
					if @predict.has_key?(args[/\S*/]) then
						puts "- TRUE"
					else
						puts "- FALSE"
					end
					""

				when "if"
					expr = parse_expr(args)
					puts "IF {#{expr.to_s}}"
					if run_expr_preproc(expr) then
						puts "- TRUE"
					else
						puts "- FALSE"
					end
					""

				when "elif"
					expr = parse_expr(args)
					puts "ELIF {#{expr.to_s}}"
					if run_expr_preproc(expr) then
						puts "- TRUE"
					else
						puts "- FALSE"
					end
					""

				when "else"
					puts "ELSE"
					""

				when "endif"
					puts "ENDIF"
					""

				when "warn"
					puts "WARN {#{args}}"
					""

				else
					puts "WARNING: undefined preprocessor argument #{$1}"
					data
					#throw Exception.new("undefined preprocessor argument #{$1}")
			end
		end

		#p data
		data
	end
end
dme = DME.new(ARGV[0])

