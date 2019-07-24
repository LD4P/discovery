class ProxyController < ApplicationController
  require 'net/http'

  def search
    require "net/http"
    # Query parameter
    query = params[:q]
    digital_collections_url = "https://digital.library.cornell.edu/?q=" + query + "&search_field=all_fields&format=json";
    url = URI.parse(digital_collections_url)
    resp = Net::HTTP.get_response(url)
    data = resp.body
    result = JSON.parse(data)
    render :json => result
  end
end