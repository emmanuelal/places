def self.near point, max_meters=nil

near_query={:$geometry=>point.to_hash}

near_query[:$maxDistance]=max_meters if max_meters

collection.find(:"geometry.geolocation"=>{:$near=>near_query})

end

def near max_meters=nil

self.class.to_places(self.class.near(location, max_meters))

end


def self.near(point, max_meters=nil)    
         max_meters=max_meters.nil? ? nil : max_meters.to_i      
         collection.find(:"geometry.geolocation"=>
         {:$near=>{:$geometry=>point.to_hash,           
              :$maxDistance=>max_meters}}
         ).each do |near_place|  
         near_places=[]
         near_places << Place.new(near_place) 
         near_places      
    end 
  end


  @result = collection.



  def self.get_address_components(sort=nil, offset=nil, limit=nil)
  
    pipe=[]
    pipe << {:$project=>{:address_components=>1, :formatted_address=>1, "geometry.geolocation":1}}
    pipe << {:$unwind=>'$address_components'}
    pipe << {:$skip=>offset} if !offset.nil?
    pipe << {:$limit=>limit} if !limit.nil?
    pipe << {:$sort=>sort} if !sort.nil?
    result = self.collection.aggregate(pipe)
  end 