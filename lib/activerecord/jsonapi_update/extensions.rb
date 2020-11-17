# frozen_string_literal: true

module ActiveRecord
  module JsonApiUpdate
    # Extensions included in ActiveRecord::Base to provide the new jsonapi methods
    module Extensions
      # Updates the model using the provided <tt>attributes</tt> in a manner that is consistent with a JSON API
      # update.
      #
      # In particular:
      #
      # > Any or all of a resource's relationships MAY be included in the resource object included in a PATCH
      # > request.
      # >
      # > If a request does not include all of the relationships for a resource, the server MUST interpret the
      # > missing relationships as if they were included with their current values. It MUST NOT interpret them
      # > as null or empty values.
      #
      # > If a relationship is provided in the relationships member of a resource object in a PATCH request,
      # > its value MUST be a relationship object with a data member. The relationship's value will be replaced
      # > with the value specified in this member.
      #
      # To accommodate this, nested hashes or arrays with the  *_attributes suffix are processed as follows:
      #
      # For hashes that have no id value, a new record is created (matching the behaviour of the normal #update
      # method).
      #
      # For hashes that have an id value, a find-and-update operation will occur (again, matching #update)
      #
      # Any existing associated records not mentioned in the *_attributes hash or array will be destroyed
      # (which is <i>not</i> how the normal #update method functions.)
      #
      # @see https://jsonapi.org/format/#crud-updating-resource-relationships
      # @param attributes [Hash] A hash of attributes to save on the model and its associations
      # @return [Boolean] True if the record successfully updated
      def jsonapi_update(attributes)
        assign_jsonapi_attributes(attributes)
        save
      end

      # Performs a JSON API compliant update on the model, throwing an exception if it fails
      # @param attributes [Hash] A hash of attributes to save on the model and its associations
      # @return [Boolean] True if the record successfully updated
      # @raise [ActiveRecord::RecordNotSaved] If the record was not updated
      # @see #json_api_update
      def jsonapi_update!(attributes)
        assign_jsonapi_attributes(attributes)
        save!
      end

      # Assigns attributes to a model (but does not save it), generating the necessary destroy objects
      # to remove any items not explicitly mentioned in any of the relationships that appear in
      # <tt>attributes</tt>
      # @param attributes [Hash] A hash of attributes to save on the model and its associations
      # @return [void]
      def assign_jsonapi_attributes(attributes)
        assign_attributes(sanitize_jsonapi_attributes(attributes))
      end

      private

      NESTED_ATTRIBUTES_SUFFIX = '_attributes'

      def sanitize_jsonapi_attributes(attributes, key_name = nil)
        key_name = key_name.to_s

        if attributes.is_a?(Array)
          _attributes = attributes.map(&method(:sanitize_jsonapi_attributes))

          if key_name.end_with?(NESTED_ATTRIBUTES_SUFFIX)
            association_ids = self.try(ids_method_name(key_name))
            return _attributes if association_ids.nil?

            new_ids = build_ids_dictionary(_attributes)

            append_delete_objects_to_array(_attributes, association_ids, new_ids)
          else
            _attributes
          end
        elsif attributes.is_a?(Hash)
          _attributes = attributes.each_with_object({}) do |(key, value), memo|
            memo[key] = sanitize_jsonapi_attributes(value, key)
          end

          if key_name.end_with?(NESTED_ATTRIBUTES_SUFFIX)
            association_ids = self.try(ids_method_name(key_name))
            return _attributes if association_ids.nil?

            new_ids = build_ids_dictionary(_attributes.values)

            append_delete_objects_to_hash(_attributes, association_ids, new_ids)
          else
            _attributes
          end
        else
          attributes
        end
      end

      def build_ids_dictionary(attributes)
        attributes.each_with_object({}) do |element, memo|
          element_wia = element.with_indifferent_access
          memo[element_wia[:id].to_s] = true if element_wia.key?(:id)
        end
      end

      def append_delete_objects_to_array(attributes, association_ids, new_ids)
        association_ids.inject(attributes.dup) do |memo, id|
          id_s = id.to_s

          if new_ids.key?(id_s)
            memo
          else
            memo + [delete_object(id_s)]
          end
        end
      end

      def append_delete_objects_to_hash(attributes, association_ids, new_ids)
        association_ids.inject(attributes.dup) do |memo, id|
          id_s = id.to_s

          if new_ids.key?(id_s)
            memo
          else
            memo.merge({ memo.keys.length.to_s => delete_object(id_s) })
          end
        end
      end

      def delete_object(id)
        { id: id, _destroy: 1 }
      end

      def ids_method_name(method_name)
        "#{method_name.chomp(NESTED_ATTRIBUTES_SUFFIX).singularize}_ids"
      end
    end
  end
end
