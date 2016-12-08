module WithoutScope
  module ActsAsRevisable
    # This module is mixed into the revision classes.
    #
    # ==== Callbacks
    #
    # * +before_restore+ is called on the revision class before it is
    #   restored as the current record.
    # * +after_restore+ is called on the revision class after it is
    #   restored as the current record.
    module Revision
      def self.included(base) #:nodoc:
        base.send(:extend, ClassMethods)

        class << base
          attr_accessor :revisable_revisable_class, :revisable_cloned_associations
        end

        base.instance_eval do
          self.table_name = revisable_class.table_name

          define_callbacks :before_restore, :after_restore

          before_create :revision_setup
          after_create  :grab_my_branches

          belongs_to  :current_revision,
                      class_name: revisable_class_name,
                      foreign_key: :revisable_original_id
          belongs_to  revisable_association_name.to_sym,
                      class_name: revisable_class_name,
                      foreign_key: :revisable_original_id

          has_many  :ancestors,
                    -> (object) {
                      associated_revisions(object).
                        where('revisable_number < ?', object.revisable_number).
                        order(revisable_number: :desc)
                    },
                    class_name: revision_class_name
          has_many  :descendants,
                    -> (object) {
                      associated_revisions(object).
                        where('revisable_number > ?', object.revisable_number).
                        order(revisable_number: :asc)
                    },
                    class_name: revision_class_name

          default_scope { where(revisable_is_current: false) }
          scope :associated_revisions,
                -> (object) {
                  where(revisable_original_id: object.revisable_original_id).
                    where(revisable_is_current: false)
                }
          scope :deleted, -> { where.not(revisable_deleted_at: nil) }
        end
      end

      def find_revision(*args)
        current_revision.find_revision(*args)
      end

      # Return the revision prior to this one.
      def previous_revision
        self.class.find_by(
          revisable_original_id: revisable_original_id,
          revisable_number: revisable_number - 1
        )
      end

      # Return the revision after this one.
      # TODO: Update to new syntax
      def next_revision
        self.class.find_by(
          revisable_original_id: revisable_original_id,
          revisable_number: revisable_number + 1
        )
      end

      # Setter for revisable_name just to make external API more pleasant.
      def revision_name=(val) #:nodoc:
        self[:revisable_name] = val
      end

      # Accessor for revisable_name just to make external API more pleasant.
      def revision_name #:nodoc:
        self[:revisable_name]
      end

      # Sets some initial values for a new revision.
      def revision_setup #:nodoc:
        now = Time.current
        prev = current_revision.revisions.first
        prev.update(revisable_revised_at: now) if prev
        self[:revisable_current_at] = now + 1.second
        self[:revisable_is_current] = false
        self[:revisable_branched_from_id] = current_revision[:revisable_branched_from_id]
        self[:revisable_type] = current_revision[:type] || current_revision.class.name
      end

      def grab_my_branches
        self.class.revisable_class.where(revisable_branched_from_id: self[:revisable_original_id]).update_all(revisable_branched_from_id: self[:id])
      end

      def from_revisable
        current_revision.for_revision
      end

      def reverting_from
        from_revisable[:reverting_from]
      end

      def reverting_from=(val)
        from_revisable[:reverting_from] = val
      end

      def reverting_to
        from_revisable[:reverting_to]
      end

      def reverting_to=(val)
        from_revisable[:reverting_to] = val
      end

      module ClassMethods
        # Returns the +revisable_class_name+ as configured in
        # +acts_as_revisable+.
        def revisable_class_name #:nodoc:
          self.revisable_options.revisable_class_name || self.name.gsub(/Revision/, '')
        end

        # Returns the actual +Revisable+ class based on the
        # #revisable_class_name.
        def revisable_class #:nodoc:
          self.revisable_revisable_class ||= self.revisable_class_name.constantize
        end

        # Returns the revision_class which in this case is simply +self+.
        def revision_class #:nodoc:
          self
        end

        def revision_class_name #:nodoc:
          self.name
        end

        # Returns the name of the association acts_as_revision
        # creates.
        def revisable_association_name #:nodoc:
          revisable_class_name.underscore
        end

        # Returns an array of the associations that should be cloned.
        def revision_cloned_associations #:nodoc:
          clone_associations = self.revisable_options.clone_associations

          self.revisable_cloned_associations ||= \
            if clone_associations.blank?
              []
            elsif clone_associations.eql? :all
              revisable_class.reflect_on_all_associations.map(&:name)
            elsif clone_associations.is_a? [].class
              clone_associations
            elsif clone_associations[:only]
              [clone_associations[:only]].flatten
            elsif clone_associations[:except]
              revisable_class.reflect_on_all_associations.map(&:name) - [clone_associations[:except]].flatten
            end
        end
      end
    end
  end
end
