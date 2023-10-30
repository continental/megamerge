# frozen_string_literal: true

# Enabled monkey patches
Rails.configuration.to_prepare do
  String.include CoreExtensions::String::IsType
  Object.include CoreExtensions::Object::Boolean
  Object.include CoreExtensions::Object::Flock
  Object.include CoreExtensions::Object::Block
  Numeric.include CoreExtensions::Numeric::Comparison
  
  Hash.include CoreExtensions::Hash::Conversion
end
