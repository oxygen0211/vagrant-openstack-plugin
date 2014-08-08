require "vagrant-openstack-plugin/config"

describe VagrantPlugins::OpenStack::Config do
  describe "defaults" do
    let(:vagrant_public_key) { Vagrant.source_root.join("keys/vagrant.pub") }

    subject do
      super().tap do |o|
        o.finalize!
      end
    end

    its(:api_key)  { should be_nil }
    its(:endpoint) { should be_nil }
    its(:flavor)   { should eq(/m1.tiny/) }
    its(:image)    { should eq(/cirros/) }
    its(:server_name) { should be_nil }
    its(:username) { should be_nil }
    its(:keypair_name) { should be_nil }
    its(:ssh_username) { should be_nil }
    its(:network) { should be_nil }
    its(:security_groups) { should be_nil }
    its(:scheduler_hints) { should be_nil }
    its(:tenant) { should be_nil }
    its(:proxy) { should be_nil }
    its(:disks) { should be_nil }
    its(:ssl_verify_peer) { should be_nil }
  end

  describe "overriding defaults" do
    [:api_key,
      :endpoint,
      :flavor,
      :image,
      :server_name,
      :username,
      :keypair_name,
      :network,
      :ssh_username,
      :security_groups,
      :scheduler_hints,
      :tenant,
      :ssl_verify_peer,
      :proxy].each do |attribute|
      it "should not default #{attribute} if overridden" do
        subject.send("#{attribute}=".to_sym, "foo")
        subject.finalize!
        subject.send(attribute).should == "foo"
      end
    end
    it "should not default disks if overridden" do
      subject.send("disks=".to_sym, {"name" => "foo", "size" => 10, "description" => "bar"})
      subject.finalize!
      subject.send("disks").should == {"name" => "foo", "size" => 10, "description" => "bar"}
    end
  end

  describe "validation" do
    let(:machine) { double("machine") }

    subject do
      super().tap do |o|
        o.finalize!
      end
    end

    context "with good values" do
      it "should validate"
    end

    context "the API key" do
      it "should error if not given"
    end

    context "the public key path" do
      it "should have errors if the key doesn't exist"
      it "should not have errors if the key exists with an absolute path"
      it "should not have errors if the key exists with a relative path"
    end

    context "the username" do
      it "should error if not given"
    end

    context "the disks" do
      it "should not error if not given"
      it "should error if non-array given"
      it "should error if non-hash array element given"
      it "should error if array element hash does not contain all three name, description or size keys"
      it "should not error if array element hash does contain all three name, description and size keys"
    end
  end
end
