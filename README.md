Update ActiveRecord instances and their associations, consistent with JSON API specification.

## Why is this needed?

The [JSON API specification](https://jsonapi.org/format/#crud-updating-resource-relationships) says the following: 

> If a relationship is provided in the relationships member of a resource object in a PATCH request, its value ... *will be replaced with the value specified in this member.*   

The example provided is particularly clear:

> ... the following PATCH request performs a complete replacement of the tags for an article:

```
PATCH /articles/1 HTTP/1.1
Content-Type: application/vnd.api+json
Accept: application/vnd.api+json

{
  "data": {
    "type": "articles",
    "id": "1",
    "relationships": {
      "tags": {
        "data": [
          { "type": "tags", "id": "2" },
          { "type": "tags", "id": "3" }
        ]
      }
    }
  }
}
```

Which, depending on your deserialization solution, would likely be interpreted as:

```ruby
article_attributes = {
  id: '1',
  tag_ids: ['2', '3']
}                                                

@article.update(article_attributes) 

@article.reload.tag_ids # => [2, 3]
```

Which would work correctly (any tags that were previously associated with the article that were not mentioned in the new `tag_ids` would be destroyed). 

However consider when your model accepts nested attributes, and you then want to specify a new tag as well as keep an old one:

```
PATCH /articles/1 HTTP/1.1
Content-Type: application/vnd.api+json
Accept: application/vnd.api+json

{
  "data": {
    "type": "articles",
    "id": "1",
    "relationships": {
      "tags": {
        "data": [
          { "type": "tags", "id": "2" },
          { "type": "tags", "id": "clientid1" }   // New tag
        ]
      }
    },
    "included": [
     {
       "type": "tag",
       "id": "clientid1",
       "attributes": {
         "name": "New Tag"
       }
     }
    ]
  }
}
```   

This will likely get processed as (assuming you're removing client ids):

```ruby
article_attributes = {
  id: '1',
  tags_attributes: {
    0: {
      id: '2'
    },
    1:  {
      name: 'New Tag'
    },
  }
} 

@article.update(article_attributes) # The new tag is given id 4  

@article.reload.tag_ids # => [2, 3, 4]
```

`@article.update(article_attributes)` correctly creates the new tag and keeps the one that should be kept (id: 2), but it *doesn't* get rid of the old one (id: 3).

That's when you need `activerecord-jsonapi_update`:

```ruby
@article.jsonapi_update(article_attributes) # The new tag is given id 4  

@article.reload.tag_ids # => [2, 4]
```
 
## Installation

Add this line to your application's Gemfile:

    gem 'activerecord-jsonapi_update'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activerecord-jsonapi_update

## Usage

`activerecord-jsonapi_update` provides 3 new methods on ActiveRecord instances:

* `jsonapi_update` instead of `update` 
* `jsonapi_update!` instead of `update!` 
* `assign_jsonapi_attributes` instead of `assign_attributes`

Each has the same method signature (arguments) as the ActiveRecord method it replaces.

For example:

```ruby
def update
  @article = Article.find(params[:id])

  if @article.jsonapi_update(allowed_params)
    render json: @article, status: :success
  end
end
``` 
                         
`jsonapi_update` does not side-step any of the normal ActiveRecord functionality (and limits itself to pre-processing the `attributes` it's provided), so in order to allow destroying nested attributes you must still explicitly permit it in the `accepts_nested_attributes` declaration.

```ruby
class Article < ActiveRecord::Base
  accepts_nested_attributes_for :tags, allow_destroy: true
end
```  

You will also have configure strong parameters correctly in your controller to permit the associated resource attributes:

```ruby
def allowed_params
  params.from_jsonapi.permit(:id, tags: [:id, :name])
end
```

## How it works

To accommodate this, nested hashes or arrays with the `_attributes` suffix are processed as follows:

* For hashes that have no id value, a new record is created (matching the behaviour of the normal #update
method).
* For hashes that have an id value, a find-and-update operation will occur (again, matching #update)
* Any existing associated records not mentioned in the `*_attributes` hash or array will be destroyed
(which is <i>not</i> how the normal `#update` method functions.)


## Should I always use jsonapi_update now?

The `jsonapi_update` method intends to be as light-weight as possible, but it does carry with it a slight overhead that depends on the size and complexity of the hash of values you're using to update your models.

It also only has any effect when:
* Strong parameters permit nested parameters to update a nested resource
* The model declares it accepts nested parameters for an associated resources that are allowed to be destroyed

So only use `jsonapi_update` when you actually want to support the replacement of the entire collection of associated resources on a particular endpoint and you have configured your controller and models to allow it.

Please see the [relevant section of the JSON API specification](https://jsonapi.org/format/#crud-updating-resource-relationships) for a full discussion of supporting or rejecting updating associated resources.
