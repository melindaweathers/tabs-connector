module TabsConnector
  module Contest
    extend ActiveSupport::Concern
    include TabsConnector

    CAMPAIGN_SETTING = {
      :name => "Contest",
      :enable_first_name => false,
      :require_first_name => false,
      :enable_last_name => false,
      :require_last_name => false,
      :enable_email => false,
      :require_email => false,
      :enable_address => false,
      :require_address => false,
      :enable_phone => false,
      :require_phone => false,
      :enable_email_confirmation => false,
      :require_email_confirmation => false,
      :enable_country => false,
      :require_country => false,
      :enable_dob => false,
      :require_dob => false,
      :enable_title => false,
      :require_title => false,
      :enable_description => false,
      :require_description => false,
      :opt_in_one_required => false,
      :opt_in_one_enabled => false,
      :opt_in_two_required => false,
      :opt_in_two_enabled => false,
      :opt_in_three_required => false,
      :opt_in_three_required => false,
    }
    MAGIC_URL = "http://cdn.vitrue.com/magic/prod/uploadabletheme/current/"

    included do
      helper_method :session_prefix
    end

    module ClassMethods
      def my_class_method
        Rails.logger.debug "---------- my_class_method"
      end
    end

    module InstanceMethods
      def my_instance_method
        Rails.logger.debug "---------- my_instance_method"
      end

      def session_prefix
        super(:campaign_token)
      end

      def write_token_to_session
        super(:campaign_token)
      end

      def write_client_id_to_session
        super(:tabs_client_id)
      end

      def get_tabs_client_id
        super(:tabs_client_id)
      end

      def get_campaign_token(debug=false)
        super(debug, :campaign_token)
      end

      def get_store_id
        if get_tabs_data
          store_id = get_tabs_data['store_id']
        else
          if ( store_id = get_current_session['store_id'] )
            store_id
          else
            store_id = 0
          end
        end
        store_id
      end

      def find_or_create_client_and_user
        @tabs_client = Client.find_or_create_by_tabs_client_id(get_tabs_client_id)
        @tabs_user = AdminUser.find_or_create_by_tabs_store_id(get_store_id) do |u|
          u.email = "#{SecureRandom.hex(6)}@vitrue.com"
          u.password = SecureRandom.hex(8)
          u.role = 'tabs_admin'
          u.client_id = @tabs_client.id
        end
      end

      def on_facebook?
        Rails.logger.debug "---------- get_tabs_data['on_fb'] is #{get_tabs_data['on_fb'].inspect}"
        Rails.logger.debug "---------- get_tabs_data['on_fb'].class is #{get_tabs_data['on_fb'].class.inspect}"
        get_tabs_data['on_fb'] == 1 ? true : false
      end

      def auto_sign_in
        raise NotImplementedError, "You must implement this method"
      end

      def load_campaign
        Rails.logger.debug "---------- TabsConnector::Contest#load_campaign"
        if get_campaign_token(true).present?
          @campaign = Campaign.find_or_create_by_token(get_campaign_token) do |c|
            c.client_id = @tabs_client.id
            c.update_attributes(CAMPAIGN_SETTING)
          end
          unless @campaign
            render :text => "Can't find or create Campaign" and return
          end
        else
          render :text => "campaign_token missing in params" and return
        end
      end

      def load_environment
        Rails.logger.debug "---------- TabsConnector::Contest#load_environment"
        @environment = Environment.find_or_create_by_campaign_id(@campaign.id) do |e|
          e.update_attributes(:name => "Tabs Environment #{@campaign.environments.count + 1}",
                              :magic_url => MAGIC_URL)
        end
        unless @environment
          render :text => "Can't find or create Environment" and return
        else
          @environment.refresh_magic_html
        end
      end

      def load_phase
        Rails.logger.debug "---------- TabsConnector::Contest#load_phase"

        return if @phase_loaded

        begin
          @phase = @environment.get_active_phase(Time.at(get_simulated_time).in_time_zone)
        rescue Exception => e
          @phase = @environment.get_active_phase
        end

        unless @phase
          render :text => "Phases are not active now" and return
        end

        @phase_loaded = true
      end
    end
    
  end
end