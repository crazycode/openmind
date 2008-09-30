module OpenIdAuthentication
  class DbStore < OpenID::Store
    def self.gc
      now = Time.now.to_i

      # remove old nonces
      nonces = Nonce.find(:all)
      nonces.each {|n| n.destroy if now - n.created > 6.hours} unless nonces.nil?
    
      # remove expired assocs
      assocs = Association.find(:all)
      assocs.each { |a| a.destroy if a.from_record.expired? } unless assocs.nil?
    end


    def get_auth_key
      unless setting = Setting.find_by_setting('auth_key')
        auth_key = OpenID::Util.random_string(20)
        setting  = Setting.create(:setting => 'auth_key', :value => auth_key)
      end

      setting.value
    end

    def store_association(server_url, assoc)
      remove_association(server_url, assoc.handle)    
      Association.create(:server_url => server_url,
                         :handle     => assoc.handle,
                         :secret     => assoc.secret,
                         :issued     => assoc.issued,
                         :lifetime   => assoc.lifetime,
                         :assoc_type => assoc.assoc_type)
    end

    def get_association(server_url, handle=nil)
      assocs = handle.blank? ? 
        Association.find_all_by_server_url(server_url) :
          Association.find_all_by_server_url_and_handle(server_url, handle)
    
      assocs.reverse.each do |assoc|
        a = assoc.from_record    
        if a.expired?
          assoc.destroy
        else
          return a
        end
      end if assocs.any?
    
      return nil
    end
  
    def remove_association(server_url, handle)
      assoc = Association.find_by_server_url_and_handle(server_url, handle)
      unless assoc.nil?
        assoc.destroy
        return true
      end
      false
    end
  
    def store_nonce(nonce)
      use_nonce(nonce)
      Nonce.create :nonce => nonce, :created => Time.now.to_i
    end
  
    def use_nonce(nonce)
      nonce = Nonce.find_by_nonce(nonce)
      return false if nonce.nil?
    
      age = Time.now.to_i - nonce.created
      nonce.destroy

      age < 6.hours # max nonce age of 6 hours
    end
  
    def dumb?
      false
    end
  end
end