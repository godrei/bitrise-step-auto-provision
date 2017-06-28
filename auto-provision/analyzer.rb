require 'xcodeproj'

def get_project_bundle_id_entitlements_map(pth)
  project_info_mapping = {}

  if File.extname(pth) == '.xcodeproj'
    project_paths = [pth]
  else
    workspace_contents_pth = File.join(pth, 'contents.xcworkspacedata')
    workspace_contents = File.read(workspace_contents_pth)
    project_paths = workspace_contents.scan(/\"group:(.*)\"/).collect do |current_match|
      return nil if current_match.end_with?('Pods/Pods.xcodeproj')

      File.join(File.expand_path('..', pth), current_match.first)
    end
  end

  project_paths.each do |project_path|
    target_info_mapping = {}

    begin
      project = Xcodeproj::Project.open(project_path)
      project.targets.each do |target|
        next if target.test_target_type?

        target.build_configuration_list.build_configurations.each do |build_configuration|
          build_settings = build_configuration.build_settings

          bundle_identifier = build_settings['PRODUCT_BUNDLE_IDENTIFIER']
          code_sign_entitlements = build_settings['CODE_SIGN_ENTITLEMENTS']

          code_sign_entitlements_path = ''
          code_sign_entitlements_path = File.join(File.expand_path('..', pth), code_sign_entitlements) unless code_sign_entitlements.to_s.empty?

          target_info_mapping[bundle_identifier] = code_sign_entitlements_path
        end
      end

      project_info_mapping[project_path] = target_info_mapping
    rescue => ex
      log_error(ex)
      log_details(ex.backtrace)
    end
  end

  project_info_mapping
end

def force_manual_code_sign(pth)
  if File.extname(pth) == '.xcodeproj'
    project_paths = [pth]
  else
    workspace_contents_pth = File.join(pth, 'contents.xcworkspacedata')
    workspace_contents = File.read(workspace_contents_pth)
    project_paths = workspace_contents.scan(/\"group:(.*)\"/).collect do |current_match|
      return nil if current_match.end_with?('Pods/Pods.xcodeproj')

      File.join(File.expand_path('..', pth), current_match.first)
    end
  end

  project_paths.each do |project_path|
    begin
      project = Xcodeproj::Project.open(project_path)
      project.targets.each do |target|
        next if target.test_target_type?

        target_id = target.uuid
        attributes = project.root_object.attributes['TargetAttributes']
        target_attributes = attributes[target_id]
        target_attributes['ProvisioningStyle'] = 'Manual'
      end

      project.save
    rescue => ex
      log_error(ex)
      log_details(ex.backtrace)
    end
  end
end
