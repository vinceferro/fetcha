require "fetcha/version"
require "active_support/concern"

module Fetcha
  extend ActiveSupport::Concern

  module ClassMethods

    def fetch(params = {})
      results = self.all
      query_scope = params['scope']
      filters = params['filter']
      sorting = params['sort']
      pages = params['page']
      search = params['search']
      results = process_scope(results, query_scope) if query_scope
      results = process_filtering(results, filters) if filters
      results = process_sorting(results, sorting) if sorting
      results = process_pagination!(results, pages) if pages
      results = process_search(results, search) if search
      results
    end

    private

    def fetchable_opts
      @fetchable_opts ||=
        {
          filtering: {},
          sorting: {},
          scopes: Set.new(),
          pagination: {
            default_size: 10,
            max_size: 50
          }
        }
    end

    def fulltext_search_on(*fields)
      include PgSearch
      self.pg_search_scope :search_full_text, against: fields, using: { trigram: { threshold: 0.1 }, tsearch: { prefix: true } }
    end

    def filterable_on(*fields)
      fields.each do |field|
        fetchable_opts[:filtering][field.to_s] = nil
      end
    end

    def sortable_on(*fields)
      fetchable_opts[:sorting] = Set.new(fields.map(&:to_s))
    end

    def scopable_with(*fields)
      fetchable_opts[:scopes] = Set.new(fields.map(&:to_s))
    end

    def paginatable(args = {})
      fetchable_opts[:pagination].keys.each do |k|
        next unless args.keys.include? k
        fetchable_opts[:pagination][k] = args[k]
      end
    end

    def process_scope(datasource, query_scope)
      datasource.send(query_scope) if (fetchable_opts[:scopes].include? query_scope.to_sym)
    end

    def process_search(datasource, search)
      datasource.search_full_text(search)
    end

    def process_filtering(datasource, filters = {})
      filter_opts = fetchable_opts[:filtering]
      includes = Set.new()
      
      real_filters = filters.select do |k| 
        next unless filter_opts.keys.include? k
        values = k.split('.')
        includes << values.first if values.second.present?
        true
      end
      results = includes.empty? ? datasource : datasource.includes(includes.to_a)

      real_filters.each do |key, value|
        results = process_operation(results, key, value)
      end
      results
    end

    def process_sorting(datasource, sorting)
      sort_params = SortParams.sorted_fields(sorting, fetchable_opts[:sorting])
      datasource = datasource.order(sort_params) if sort_params
      datasource
    end

    def process_operation(datasource, field, value)
      results = datasource
      if value.is_a? Hash
        value.each do |operation, value|
          results = send("#{operation}_filter", results, field, value)
        end
      else
        results = results.where({field => value})
      end
      results
    end

    def process_pagination!(datasource, page = {})
      page_opts = fetchable_opts[:pagination]
      max_size = page_opts[:max_size]
      size = (page['size'] || page_opts[:default_size]).to_i
      number = (page['number'] || '1').to_i - 1
      raise ForbiddenError if size > max_size || size < 1 || number < 0
      offset = number * size
      datasource = datasource.offset(offset).limit(size)
    end

    def presence_filter(datasource, field, value)
      if value
        datasource.where.not(field => nil)
      else
        datasource.where(field => nil)
      end
    end

    def contains_filter(datasource, field, value)
      datasource.where("#{field} ilike ?", "%#{value}%")
    end

    def starts_with_filter(datasource, field, value)
      datasource.where("#{field} ilike ?", "#{value}%")
    end

    def ends_with_filter(datasource, field, value)
      datasource.where("#{field} ilike ?", "%#{value}")
    end

    def method_missing(name, *args, block)
      raise ForbiddenError if name.match /.*_filter$/
      super
    end
  end

  module SortParams
    def self.sorted_fields(sort, allowed_set)
      fields = sort.to_s.split(',')

      ordered_fields = convert_to_ordered_hash(fields)
      filtered_fields = ordered_fields.select { |k| allowed_set.include? k }

      filtered_fields.present? ? filtered_fields : nil
    end

    def self.convert_to_ordered_hash(fields)
      fields.each_with_object({}) do |field, hash|
        if field.start_with?('-')
          field = field[1..-1]
          hash[field] = :desc
        else
          hash[field] = :asc
        end
      end
    end
  end


  class ForbiddenError < StandardError; end
end
