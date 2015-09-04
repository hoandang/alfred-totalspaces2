require "totalspaces2"
#require "benchmark"

# SPACE_ADD, SPACE_REMOVE, SPACE_RENAME are set in the Aflred Workflow config window
SPACE_MENU = "_menu"
ACT_CHANGE = "_%ch"
ACT_RENAME = "_%rn"
ACT_ADD	   = "_%ad"
ACT_REMOVE = "_%rm"

$ts = TotalSpaces2

# Workflow filter
class FilterResult
	# TODO: Refactor to 'static constructor'.
	def self.menu_items()
		[ChangeFilter, RenameFilter, AddFilter, RemoveFilter]
	end

	# Abstract methods
	def arg() end
	def autocomplete() end
	def valid?() true end
	def title() end
	def subtitle() end
	def action?() true end
	def xml_attr
		r = ""
		if action?
			r << "arg='#{arg}'"
		elsif
			_ac = autocomplete.to_s == "" ? "" : autocomplete + " "
			r << "autocomplete='#{_ac}'"
		end
		r << (valid? ? "" : " valid='no'")
	end	

	# Base subclasses
	class BaseFilter < FilterResult
		def valid?() false end
		def action?() false end
	end

	class BaseAction < FilterResult
		@index
		@name
		def initialize(index, name = nil)
			@index = index
			@name = name
		end
		def arg_prefix() end
		def arg() "#{arg_prefix},#{@index}" end
	end

	# Concrete subclasses
	class MenuFilter < BaseFilter
		def autocomplete() SPACE_MENU end
		def title() "Other filters menu '...'" end
	end

	class ChangeFilter < BaseFilter
		def title() "Change space" end
		def subtitle
			"Enter a name of space to change to"
		end
	end

	class ChangeAction < BaseAction
		def arg_prefix() ACT_CHANGE end
		def valid?() $ts.current_space != @index end
		def title() @name + (valid? ? "" : " ✓") end
		def subtitle
			valid? ? "Change to space named '#{@name}'" :
				"This is current space"
		end
	end

	class RenameFilter < BaseFilter
		def autocomplete() SPACE_RENAME end
		def title() "Rename space" end
		def subtitle
			"Enter a new name for current space"
		end
	end

	class RenameAction < BaseAction
		def arg_prefix() ACT_RENAME end
		def arg() "#{arg_prefix},#{@name}" end
		def title
			"Current space will be renamed to '#{@name}'"
		end
	end

	class AddFilter < BaseFilter
		def autocomplete() SPACE_ADD end
		def title() "Add space" end
		def subtitle
			"Enter a name for new space"
		end
	end

	class AddAction < BaseAction
		def arg_prefix() ACT_ADD end
		def arg() "#{arg_prefix},#{@name}" end
		def title
			"Add a new space named '#{@name}'"
		end
	end

	class RemoveFilter < BaseFilter
		def autocomplete() SPACE_REMOVE end
		def title() "Remove space" end
		def subtitle
			"Enter a name of space to remove"
		end
	end

	class RemoveAction < BaseAction
		def arg_prefix() ACT_REMOVE end
		def title() @name end
		def subtitle
			"Remove space named '#{@name}'"
		end
	end
end

class InputFilter
	def self.starts_with_regex(starting_text)
		Regexp.new("^#{starting_text}.*", Regexp::IGNORECASE)
	end

	def self.filter(query)
		q1, q2 = query.split(" ", 2)
		q1 = q1.to_s
		regex = starts_with_regex(q2)
		if q1.casecmp(SPACE_MENU) == 0 && q2
			FilterResult.menu_items.each do |fc|
				filter = fc.new
				if regex =~ filter.title
					yield filter
				end
			end
		elsif q1.casecmp(SPACE_RENAME) == 0 && q2
			yield FilterResult::RenameAction.new($ts.current_space, q2)
		elsif q1.casecmp(SPACE_ADD) == 0 && q2
			yield FilterResult::AddAction.new(nil, q2)
		elsif q1.casecmp(SPACE_REMOVE) == 0 && q2
			n = $ts.number_of_spaces
			for i in 1..n
				name = $ts.name_for_space(i)
				if !(regex =~ name) then next end
				yield FilterResult::RemoveAction.new(i, name)
			end	
		else
			if q1 == ""
				yield FilterResult::MenuFilter.new
			end
			regex = starts_with_regex(query)
			n = $ts.number_of_spaces
			for i in 1..n
				name = $ts.name_for_space(i)
				if !(regex =~ name) then next end
				yield FilterResult::ChangeAction.new(i, name)
			end	
		end
	end

	def self.populate_results(query)
		xml = "<items>"
		filter(query) do |f|
			xml << "<item #{f.xml_attr}><title>#{f.title}</title>"
			xml << "<subtitle>#{f.subtitle}</subtitle></item>"
		end
		puts xml << "</items>"
	end
end

# Workflow actions
class ActionRunner

	@@actions

	def self.init
		@@actions = Hash.new
		@@actions[ACT_CHANGE] = ChangeAction
		@@actions[ACT_RENAME] = RenameAction
		@@actions[ACT_ADD]	  = AddAction
		@@actions[ACT_REMOVE] = RemoveAction
	end

	# Base members
	def exec(value)
	end

	# Subclasses
	class ChangeAction < ActionRunner
		def exec(value)
			$ts.move_to_space(value.to_i)
		end
	end

	class RenameAction < ActionRunner
		def exec(value)
			$ts.set_name_for_space($ts.current_space, value)
		end
	end	
	
	class AddAction < ActionRunner
		def exec(value)
			n = $ts.number_of_spaces
			$ts.add_desktops(1)
			$ts.set_name_for_space(n + 1, value)
			$ts.move_to_space(n + 1)
		end
	end	
	
	class RemoveAction < ActionRunner
		def exec(value)
			$ts.move_space_to_position(value.to_i, $ts.number_of_spaces)
			$ts.remove_desktops(1)
		end
	end	

	def self.exec_action(query)
		arg, value = query.split(",")
		@@actions[arg].new.exec(value)
		puts query
	end
end

ActionRunner.init()