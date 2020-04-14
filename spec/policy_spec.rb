require 'cfn-leaprog/policy'

describe Policy do
  context 'policy with iam and sqs actions and resources' do
    it 'generates a hash broken out by iam and sqs with the actions and resources filtered down' do
      policy_document = {
        "Version"=>"2012-10-17",
        "Statement"=>{
          "Effect"=>"Allow",
          "Action"=>["iam:DeleteLoginProfile", "sqs:DeleteQueue", "iam:CreateUser", "iam:ListUserTags", "iam:TagUser", "iam:UntagUser", "sqs:CreateQueue", "iam:ListAccessKeys", "sqs:GetQueueAttributes", "iam:DeleteUser", "iam:CreateGroup", "iam:DeleteGroupPolicy", "iam:DeleteGroup", "iam:GetGroupPolicy"],
          "Resource"=>"*"
        }
      }
      candidate_resources = Set.new(
        [
          "arn:aws:iam::1111111111111111:user/cfn-least-privilege-role-generator1584714396-MyQueueUser-1Q31GRUMECDHV",
          "arn:aws:iam::1111111111111111:user/cfn-least-privilege-role-generator1584714396-MyPublishUser-1C9NNDXC1G1HP",
          "sqs:*",
          "arn:aws:iam::1111111111111111:user/cfn-least-privilege-role-generator1584714436-MyQueueUser-13XOGKN43YO4Q",
          "arn:aws:iam::1111111111111111:user/cfn-least-privilege-role-generator1584714436-MyPublishUser-CZWVF3LALAK3",
          "arn:aws:iam::1111111111111111:group/cfn-least-privilege-role-generator158471450-MyRDMessageQueueGroup-Z8GP4A0NV979",
          "group cfn-least-privilege-role-generator158471452-MyRDMessageQueueGroup-1SL786CC8JBFK",
          "user cfn-least-privilege-role-generator1584714525-MyPublishUser-Y55CUM6QYJOJ",
          "user cfn-least-privilege-role-generator1584714525-MyQueueUser-XXLB4B64I3YM",
          "group cfn-least-privilege-role-generator158471454-MyRDMessageQueueGroup-HFZ72CZ62BGY",
          "user cfn-least-privilege-role-generator1584714547-MyQueueUser-1041WDQIBDD1J",
          "user cfn-least-privilege-role-generator1584714547-MyPublishUser-AI4K5KIRFKTR"
        ]
      )
      expected_policy = {
        "iam"=>Policy::Statement.construct(
          ["iam:DeleteLoginProfile", "iam:CreateUser", "iam:ListUserTags", "iam:TagUser", "iam:UntagUser", "iam:ListAccessKeys", "iam:DeleteUser", "iam:CreateGroup", "iam:DeleteGroupPolicy", "iam:DeleteGroup", "iam:GetGroupPolicy"],
          ["arn:aws:iam::1111111111111111:user/cfn-leaprog*-MyQueueUser-*", "arn:aws:iam::1111111111111111:user/cfn-leaprog*-MyPublishUser-*", "arn:aws:iam::1111111111111111:group/cfn-leaprog*-MyRDMessageQueueGroup-*"]
        ),
        "sqs"=>Policy::Statement.construct(
          ["sqs:DeleteQueue", "sqs:CreateQueue", "sqs:GetQueueAttributes"],
          []
        )
      }
      actual_policy = Policy.new.reorganize_statements_by_service(policy_document, candidate_resources)
      expect(actual_policy).to eq(expected_policy)
    end
  end
end