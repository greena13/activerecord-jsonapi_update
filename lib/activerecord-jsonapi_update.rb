# frozen_string_literal: true

require 'active_support/lazy_load_hooks'
require 'activerecord/jsonapi_update/extensions'

ActiveSupport.on_load(:active_record) do
  include ActiveRecord::JsonApiUpdate::Extensions
end
