json.cache! @post do
  json.extract! @post, :title, :body, :created_at, :updated_at
end