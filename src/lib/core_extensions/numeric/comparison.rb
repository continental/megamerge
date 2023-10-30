# frozen_string_literal: true

module CoreExtensions
  module Numeric
    module Comparison
      def clamp(min, max)
        [[self, max].min, min].max
      end
    end
  end
end
