json.array!(@posts) do |post|
  json.cache! post do
    json.extract! post, :title, :updated_at
    json.url post_url(post, format: :json)
  end
end