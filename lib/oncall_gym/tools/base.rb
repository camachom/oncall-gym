module OncallGym
    module Tools
        class Base
            def call(params)
                start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            
                # Validate parameters
                errors = validate_params(params)
                return Result.failure(tool_name: self.class.tool_name, errors: errors) if errors.any?
            
                # Apply defaults
                params_with_defaults = apply_defaults(params)
            
                # Execute
                data = execute(params_with_defaults)
            
                execution_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
            
                Result.success(
                  tool_name: self.class.tool_name,
                  data: data,
                  execution_time_ms: execution_time
                )
              rescue StandardError => e
                Result.failure(tool_name: self.class.tool_name, errors: [e.message])
            end
            
            def execute(params)
                raise NotImplementedError
            end

            private

            def apply_defaults(params)
                if params[:limit].nil?
                    params[:limit] = 10
                end

                params
            end

            def validate_params(params)
                errors = []

                self.class.parameter_schema[:required].each do |req|
                    if params[req].nil?
                        errors << "Missing #{req}"
                        next
                    end

                    type = self.class.parameter_schema[:types][req]
                    unless params[req].is_a?(type)
                        errors << "#{req} must be of type #{type}"
                    end
                end
                
                errors
            end
        end
    end
end
        
