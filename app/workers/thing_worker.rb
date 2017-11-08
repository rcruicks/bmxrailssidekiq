class ThingWorker

  include Sidekiq::Worker

  def perform(count)

    count.times do

      thing_uuid = UUIDTools::UUID.random_create.to_s
      Thing.create :title =>"New Thing (#{thing_uuid})", :description =>
"Description for thing #{thing_uuid}"
    end

  end

end
