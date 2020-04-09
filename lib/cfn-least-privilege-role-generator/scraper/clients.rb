# frozen_string_literal: true

require 'aws-sdk-iam'
require 'aws-sdk-cloudformation'

module Clients
  def iam_client
    unless @iam_client
      @iam_client = Aws::IAM::Client.new
    end
    @iam_client
  end

  def iam_resource
    unless @iam_resource
      @iam_resource =  Aws::IAM::Resource.new
    end
    @iam_resource
  end

  def cfn_client
    unless @cfn_client
      @cfn_client = Aws::CloudFormation::Client.new
    end
    @cfn_client
  end

  def cfn_resource(cfn_client)
    Aws::CloudFormation::Resource.new(client: cfn_client)
  end
end