module OncallGym
    module Tools
        class Registry
            def initialize
                @tools = {}
            end

            def call(tool_name, params)
                tool = get(tool_name)
                tool.call(params)
            end

            def register(tool_class)
                unless tool_class.respond_to?(:tool_name) && tool_class.tool_name
                    raise OncallGym::ValidationError, "missing tool_name"
                end

                raise OncallGym::ValidationError, "tool already registered" if registered?(tool_class.tool_name)

                @tools[tool_class.tool_name] = tool_class
            end

            def registered?(tool_name)
                !!@tools[tool_name]
            end

            def get(tool_name)
                raise OncallGym::ToolNotFoundError, "unknown tool" unless registered?(tool_name)
                @tools[tool_name].new
            end

            def tool_names
                @tools.keys
            end

            def tool_schemas
                schemas = {}

                @tools.each do |k,v|
                    schemas[k] = {
                        parameters: v.parameter_schema,
                        description: v.description
                    }
                end

                schemas
            end
        end
    end
end