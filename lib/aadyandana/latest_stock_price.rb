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
        stocks = paginate(stocks, page, limit)

        stocks || []
      end

      def price_all
        get
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
        stocks = stocks.select { |stock| stock[:identifier] == @params[:identifier] } if @params[:identifier]
        stocks = stocks.select { |stock| stock[:symbol] == @params[:symbol] } if @params[:symbol]
        stocks = stocks.select { |stock| stock[:meta][:companyName] == @params[:company_name] } if @params[:company_name]
        stocks = stocks.select { |stock| stock[:meta][:industry] == @params[:industry] } if @params[:industry]
        stocks = stocks.select { |stock| stock[:meta][:isin] == @params[:isin] } if @params[:isin]

        stocks
      end
    end
  end
end
