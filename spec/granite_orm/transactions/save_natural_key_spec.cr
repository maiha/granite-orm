require "../../spec_helper"

{% for adapter in GraniteExample::ADAPTERS %}
module {{adapter.capitalize.id}}
  describe "(Natural Key){{ adapter.id }} #save" do
    it "fails when a primary key is not set" do
      kv = Kvs.new
      kv.save.should be_false
      kv.errors.first.message.should eq "Primary key('k') cannot be null"
    end

    it "creates a new object when a primary key is given" do
      kv = Kvs.new
      kv.k = "foo"
      kv.save.should be_true

      kv = Kvs.find("foo").not_nil!
      kv.k.should eq("foo")
    end

    it "updates an existing object" do
      kv = Kvs.new
      kv.k = "foo"
      kv.v = "1"
      kv.save.should be_true

      kv.v = "2"
      kv.save.should be_true
      kv.k.should eq("foo")
      kv.v.should eq("2")
    end
  end

  describe "(Natural Key){{ adapter.id }} usecases" do
    it "CRUD" do
      Kvs.clear

      ## Create
      port = Kvs.new(k: "mysql_port", v: "3306")
      port.new_record?.should be_true
      port.save.should be_true
      port.v.should eq("3306")
      Kvs.count.should eq(1)

      ## Read
      port = Kvs.find("mysql_port").not_nil!
      port.v.should eq("3306")
      port.new_record?.should be_false

      ## Update
      port.v = "3307"
      port.new_record?.should be_false
      port.save.should be_true
      port.v.should eq("3307")
      Kvs.count.should eq(1)

      ## Delete
      port.destroy.should be_true
      Kvs.count.should eq(0)
    end

    it "creates a new record twice" do
      Kvs.clear

      # create a new record
      port = Kvs.new(k: "mysql_port", v: "3306")
      port.new_record?.should be_true
      port.save.should be_true
      port.v.should eq("3306")
      Kvs.count.should eq(1)

      # create a new record again
      port = Kvs.new(k: "mysql_port", v: "3306")
      port.new_record?.should be_true
      port.save.should be_true
      port.v.should eq("3306")
      Kvs.count.should eq(2)
    end
  end
end
{% end %}
