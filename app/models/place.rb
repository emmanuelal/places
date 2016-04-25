require'mongo'
require 'json'

Mongo::Logger.logger.level = ::Logger::INFO
Mongo::Logger.logger.level = ::Logger::DEBUG

class Place
      include ActiveModel::Model
      attr_accessor :id , :formatted_address ,:location , :address_components

	  MONGO_URL='mongodb://localhost:27017'
    MONGO_DATABASE='places_development'
    PLACE_COLLECTION='places'
    def persisted?
       !@id.nil?
    end
    def self.mongo_client
    	 url=ENV['MONGO_URL'] ||= MONGO_URL
         database=ENV['MONGO_DATABASE'] ||= MONGO_DATABASE 
         db = Mongo::Client.new(url)
         @@db=db.use(database)
    end	

    def self.collection
    	collection=ENV['PLACE_COLLECTION'] ||= PLACE_COLLECTION
        return mongo_client[collection]
    end


    def self.load_all( file )	
        path = File.read(file)
        hash = JSON.parse(path)
        if hash.empty?
            p "unable to complete operation"
        else    
            self.collection.insert_many(hash)
      end     
    end	


    def initialize(hash={})
        Rails.logger.debug("instantiating places (#{hash})")
        #switch between both internal and external views of id and population
        @id= hash[:_id].to_s
        @address_components=[]
        if hash[:address_components]
           hash[:address_components]
        .each {|r| @address_components << AddressComponent.new(r) }
       end  
        @formatted_address=hash[:formatted_address]
        @location = Point.new(hash[:geometry][:geolocation])
     end


    def self.find_by_short_name(short_name)
        collection.find(:"address_components.short_name" => short_name)
    end  


    def self.to_places(view)
        places = []
        view.each do |v|
        places << Place.new(v)
        end
        return places
    end
    

    def self.find(id)    
        Rails.logger.debug{ "getting #{self}"}
        result =collection.find(_id: BSON::ObjectId.from_string(id)).first 
        return result.nil? ? nil : Place.new(result)
    end
  
  
  
    def self.all(offset=0, limit=nil)
        if !limit.nil?
           docs = collection.find.skip(offset).limit(limit)
        else
           docs = collection.find.skip(offset)
        end
           docs.map { |doc| Place.new(doc) }
    end

    def destroy
        self.class.collection.find(:_id => BSON::ObjectId.from_string(@id)).delete_one
    end

    def self.get_address_components(sort=nil, offset=nil, limit=nil)
        pipe=[]
        pipe << {:$project=>{:address_components=>1, :formatted_address=>1, "geometry.geolocation":1}}
        pipe << {:$unwind=>'$address_components'}
        pipe << {:$sort=>sort} if !sort.nil?
        pipe << {:$skip=>offset} if !offset.nil?
        pipe << {:$limit=>limit} if !limit.nil?
       result = collection.aggregate(pipe)
    end 
      
      def self.get_country_names 
          pipe=[]
          pipe << {:$project=>{"address_components.long_name"=>1, "address_components.types"=>1 }}
          pipe << {:$unwind=> "$address_components"}
          pipe << {:$match=>{"address_components.types"=>"country" }}
          pipe << {:$group=>{_id:'$address_components.long_name'}}
          result = collection.find().aggregate(pipe)
          return result.to_a.map {|h| h[:_id]}  
          

        end
     
     def self.find_ids_by_country_code(country)
          pipe = []
          pipe << {:$unwind=> "$address_components" }
          pipe << {:$match=>{"address_components.short_name"=> country }}
          pipe << {:$project=>{ :_id=>1 }}
          result = collection.find().aggregate(pipe)
          return result.map {|doc| doc[:_id].to_s }
     end

    def self.create_indexes
        db = Place.collection
        db.indexes.create_one({:"geometry.geolocation"=> Mongo::Index::GEO2DSPHERE })
      
    end


    def self.remove_indexes
        db = Place.collection
        db.indexes.drop_one("geometry.geolocation_2dsphere")
    end

   def self.near(point, max_meters=nil)
       near_query={:$geometry=>point.to_hash}
       near_query[:$maxDistance]=max_meters if max_meters
       collection.find(:"geometry.geolocation"=>{:$near=>near_query})
    end
    
     def near(max_meters=nil)
         max_meters = max_meters.to_i if !max_meters.nil?
         near_points = []
         if !max_meters.nil?
              Place.collection.find(
              {'geometry.geolocation': 
              {'$near': @location.to_hash, :$maxDistance => max_meters}
              }).each { |p|  near_points << Place.new(p) }
         else
             Place.collection.find(
             {'geometry.geolocation': 
             {'$near': @location.to_hash}} ).each { |p| near_points << Place.new(p) }
          end
             return near_points
          end

   def photos(offset=0, limit=0)
       self.class.mongo_client.database.fs.find("metadata.place": BSON::ObjectId.from_string(@id) ).map { |photo|
       Photo.new(photo) }
    end 
end	

