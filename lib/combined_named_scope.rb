module PincExtensions
  module ActiveRecord
    module CombinedNamedScope
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods

        # Note that proxy_options for named_scopes defined using this method show only the proxy_options of the
        # last scope in the array returned by the block (or the hash itself if the last element is a hash).
        #
        # Combined named scopes can be further combined.
        #
        # This is a Rails 2.x specific hack. There are better ways to do this in rails 3.
        def combined_named_scope(name, block)
          name = name.to_sym

          scopes[name] = lambda do |parent_scope, *args|
            options_list = block.call(*args) # Should return an array whose elements can be scopes (i.e. Asset.in_yard)
                                             # or hashes that can be given as a parameter to ActiveRecord::named_scope
            options_list ||= [{}]
            options_list = [ options_list ] if options_list.kind_of?(Hash)
            options_list = [{}] if options_list.empty?
            options_list.map! { |options| 
              if options.respond_to?(:proxy_options)
                options_list_for_scope, scope = [], options
                while scope.respond_to?(:proxy_options) do
                  options_list_for_scope << scope.proxy_options
                  scope = ( scope.respond_to?(:proxy_scope) ? scope.proxy_scope : nil )
                end
                options_list_for_scope
              else options
              end
            }.flatten!

            first_scope = ::ActiveRecord::NamedScope::Scope.new(parent_scope, options_list.first)
            options_list[1..-1].inject(first_scope) do |last_scope, options|
              ::ActiveRecord::NamedScope::Scope.new(last_scope, options)
            end
          end

          singleton_class.send :define_method, name do |*args|
            scopes[name].call(self, *args)
          end
        end

      end

    end
  end
end

class ActiveRecord::Base
  include PincExtensions::ActiveRecord::CombinedNamedScope
end
