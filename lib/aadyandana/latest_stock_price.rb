# frozen_string_literal: true

require_relative "latest_stock_price/version"

module Aadyandana
  module LatestStockPrice
    class Error < StandardError; end

    # LatestStockPrice is responsible for fetching the latest stock price information
    # from the API. It provides methods to retrieve stock prices and related data.
    #
    # Example usage:
    #
    #   client = Aadyandana::LatestStockPrice::Client.new(api_key, params)
    #   stock = client.price
    #   stocks = client.prices
    #   stocks = client.price_all
    #
    # Attributes:
    #
    # - api_key: The API key used for authentication with the stock price API.
    # - params: Any parameter(s) related to filter, sorting and pagination
    class Client
      include HTTParty
      base_uri "https://latest-stock-price.p.rapidapi.com"

      def initialize(api_key, params = {})
        @api_key = api_key
        @params = params

        @datetime_attrs = [ "lastUpdateTime" ]
        @string_meta_attrs = [ "companyName", "industry", "isin" ]
        @string_attrs = [ "identifier", "symbol" ] + @string_meta_attrs
      end

      def price
        stocks = get

        stocks = filter(stocks)

        raise Error, "Error fetching data: Bad Request" unless stocks.length == 1

        stocks.first
      end

      def prices
        page = (@params[:page] || 1).to_i
        limit = (@params[:limit] || 10).to_i
        
        stocks = get
        stocks = filter(stocks)
        stocks = sort(stocks, @params[:sort]) if @params[:sort]
        stocks = paginate(stocks, page, limit)

        stocks || []
      end

      def price_all
        stocks = get

        stocks = sort(stocks, @params[:sort]) if @params[:sort]

        stocks
      end

      private

      def headers
        {
          "X-RapidAPI-Key" => @api_key,
          "X-RapidAPI-Host" => "latest-stock-price.p.rapidapi.com"
        }
      end

      def get
        response = self.class.get(
          "/any",
          {
            headers: headers
          }
        )

        raise Error, "Error fetching data: #{response.message}" unless response.success?

        response.parsed_response
      end

      def paginate(stocks, page = 1, limit = 10)
        start_index = (page - 1) * limit
        end_index = start_index + limit - 1

        stocks[start_index..end_index]
      end

      def filter(stocks)
        stocks = stocks.select { |stock| stock["identifier"] == @params[:identifier] } if @params[:identifier]
        stocks = stocks.select { |stock| stock["symbol"] == @params[:symbol] } if @params[:symbol]
        stocks = stocks.select { |stock| stock["meta"]["companyName"] == @params[:company_name] } if @params[:company_name]
        stocks = stocks.select { |stock| stock["meta"]["industry"] == @params[:industry] } if @params[:industry]
        stocks = stocks.select { |stock| stock["meta"]["isin"] == @params[:isin] } if @params[:isin]

        stocks
      end
    
      def sort(stocks, sort)
        field, type = sort.split(".")
    
        stocks = stocks.sort_by do |stock|
          value = stock[field]
    
          if @datetime_attrs.include? field
            value = DateTime.parse(value).to_time.to_i
            value *= -1 if type == "desc"
          elsif @string_attrs.include? field
            value = stock["meta"][field] if @string_meta_attrs.include? field
            value = value.present? ? value.downcase : "zzz"
          else
            value = value == "-" ? Float::INFINITY : value.to_f
            value *= -1 if value != Float::INFINITY and type == "desc"
          end
    
          value
        end
    
        stocks = stocks.reverse! if @string_attrs.include? field and type == "desc"
    
        stocks
      end
    end
  end
end
