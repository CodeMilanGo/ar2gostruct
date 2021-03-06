module Ar2gostruct
  class Converter
    def initialize(klass, option = {})
      @klass = klass
      @max_col_size = 0
      @max_type_size = 0
      @plural = option[:plural]
      @orm = option[:orm]
      @association = option[:association]
    end
    attr_accessor :klass, :max_col_size, :max_type_size, :plural, :orm, :association

    def convert!
      get_schema_info
    end

    private

      def get_schema_info
        info = "// Table name: #{self.klass.table_name}\n"
        struct_name = get_struct_name
        info << "type #{struct_name} struct {\n"

        self.max_col_size = get_max_col_size
        self.max_type_size = get_max_type_size

        self.klass.columns.each do |col|
          tags = []

          # add json tag
          tags << json_tag(col)

          if self.orm
            orm_options = get_orm_options(col)
            tags << orm_options if orm_options && orm_options.length > 0
          end

          col_type = col.type.to_s
          case col_type
          when "integer"
            type = CONST::TYPE_MAP["integer(#{col.limit})"] || "int32"
            type = "u#{type}" if col.sql_type.match("unsigned").present?
          else
            type = CONST::TYPE_MAP[col_type] || "string"
          end

          info << sprintf("\t%-#{self.max_col_size}.#{self.max_col_size}s%-#{self.max_type_size}.#{self.max_type_size}s`%s`\n", col.name.camelize, type, tags.join(" "))

        end
        info << get_associations if self.association

        info << "}\n\n"
        return info
      end

      def get_max_col_size
        col_name_max_size = self.klass.column_names.collect{|name| name.size}.max || 0
        assoc_max_size = if self.association
          self.klass.reflect_on_all_associations.collect{|assoc| assoc.name.to_s.size}.max || 0
        else
          0
        end
        type_max_size = Ar2gostruct::CONST::TYPE_MAP.collect{|key, value| key.size}.max || 0
        [col_name_max_size + 1, assoc_max_size, type_max_size].max
      end

      def get_max_type_size
        assoc_max_size = if self.association
          self.klass.reflect_on_all_associations.collect{|assoc| assoc.name.to_s.size + 2}.max || 0
        else
          0
        end
        type_max_size = Ar2gostruct::CONST::TYPE_MAP.collect{|key, value| key.size}.max || 0
        [assoc_max_size, type_max_size].max
      end

      def get_orm_options(col)
        tags ||= []
        self.orm.split(",").each do |orm_name|
          builder = get_orm_builder orm_name
          if builder
            option = builder.get_option col
            tags << option if option
          end
        end
        return tags
      rescue => e
        []
      end

      def get_orm_builder(orm_name)
        prefix = "Ar2gostruct::Builder::ORM::"
        builder = if Object.const_defined?("#{prefix}#{orm_name.upcase}")
          "#{prefix}#{orm_name.upcase}"
        elsif Object.const_defined?("#{prefix}#{orm_name.camelize}")
          "#{prefix}#{orm_name.camelize}"
        end
        return builder.constantize.new(self.klass) if builder
      end

      def get_struct_name
        if self.plural
          self.klass.table_name.camelize
        else
          self.klass.to_s.tr_s('::', '')
        end
      end

      def get_associations
        builder = Ar2gostruct::Builder::Association.new(self.klass, self.max_col_size, self.max_type_size)
        builder.get_schema_info
      end

      def json_tag(col)
        "json:\"#{col.name}\""
      end

  end
end