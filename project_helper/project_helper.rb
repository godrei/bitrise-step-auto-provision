require 'xcodeproj'
require 'json'
require 'plist'

# ProjectHelper ...
class ProjectHelper
  def initialize(project_or_workspace_path)
    extname = File.extname(project_or_workspace_path)
    case extname
    when '.xcodeproj'
      @project_path = project_or_workspace_path
    when '.xcworkspace'
      @workspace_path = project_or_workspace_path
    else
      raise "unkown project extension: #{extname}, should be: .xcodeproj or .xcworkspace"
    end
  end

  private

  def contained_projects
    return [@project_path] unless @workspace_path

    workspace = Xcodeproj::Workspace.new_from_xcworkspace(@workspace_path)
    workspace_dir = File.dirname(@workspace_path)
    project_paths = []
    workspace.file_references.each do |ref|
      pth = ref.path
      next unless File.extname(pth) == '.xcodeproj'
      next if pth.end_with?('Pods/Pods.xcodeproj')

      project_path = File.expand_path(pth, workspace_dir)
      project_paths << project_path
    end

    project_paths
  end

  def runnable_target?(target)
    return false unless target.is_a?(Xcodeproj::Project::Object::PBXNativeTarget)

    product_reference = target.product_reference
    return false unless product_reference

    product_reference.path.end_with?('.app', '.appex')
  end

  public

  def xcodebuild_target_build_settings(project, target)
    cmd = "xcodebuild -showBuildSettings -project \"#{project}\" -target \"#{target}\""
    out = `#{cmd}`
    raise "#{cmd} failed, out: #{out}" unless $CHILD_STATUS.success?

    settings = {}
    lines = out.split(/\n/)
    lines.each do |line|
      line = line.strip
      next unless line.include?(' = ')
      split = line.split(' = ')
      next unless split.length == 2
      settings[split[0]] = split[1]
    end

    settings
  end

  def bundle_id_build_settings(build_settings)
    bundle_id = build_settings['PRODUCT_BUNDLE_IDENTIFIER']

    if bundle_id.to_s.empty?
      info_plist_path = build_settings['INFOPLIST_FILE']
      raise 'failed to to determine bundle id: xcodebuild -showBuildSettings does not contains PRODUCT_BUNDLE_IDENTIFIER nor INFOPLIST_FILE' if info_plist_path.to_s.empty?
      info_plist = Plist.parse_xml(info_plist_path)
      bundle_id = info_plist['CFBundleIdentifier']
      raise 'failed to to determine bundle id: xcodebuild -showBuildSettings does not contains PRODUCT_BUNDLE_IDENTIFIER nor Info.plist' if bundle_id.to_s.empty? || bundle_id.to_s.include?('$')
    end

    bundle_id
  end

  def project_targets_map
    project_targets = {}

    project_paths = contained_projects
    project_paths.each do |project_path|
      targets = []

      project = Xcodeproj::Project.open(project_path)
      project.targets.each do |target|
        next unless runnable_target?(target)

        targets.push(target.name)
      end

      project_targets[project_path] = targets
    end

    project_targets
  end

  def project_target_bundle_id_map
    project_target_bundle_id = {}

    project_targets = project_targets_map
    project_targets.each do |path, targets|
      target_bundle_id = {}

      targets.each do |target|
        settings = xcodebuild_target_build_settings(path, target)
        bundle_id = bundle_id_build_settings(settings)
        target_bundle_id[target] = bundle_id
      end

      project_target_bundle_id[path] = target_bundle_id
    end

    project_target_bundle_id
  end

  def project_target_entitlements_map
    project_target_entitlements = {}

    project_targets = project_targets_map
    project_targets.each do |path, targets|
      target_entitlements = {}

      targets.each do |target|
        entitlements = []
        settings = xcodebuild_target_build_settings(path, target)
        entitlements_path = settings['CODE_SIGN_ENTITLEMENTS']
        unless entitlements_path.to_s.empty?
          project_dir = File.dirname(path)
          entitlements_path = File.join(project_dir, entitlements_path)
          entitlements = Plist.parse_xml(entitlements_path)
        end

        target_entitlements[target] = entitlements
      end

      project_target_entitlements[path] = target_entitlements
    end

    project_target_entitlements
  end

  def force_code_sign_properties(project_path, target, development_team, code_sign_identity, provisioning_profile_uuid)
    project = Xcodeproj::Project.open(project_path)
    project.targets.each do |target_obj|
      next if target_obj.name == target

      # force manual code singing
      target_id = target_obj.uuid
      attributes = project.root_object.attributes['TargetAttributes']
      target_attributes = attributes[target_id]
      target_attributes['ProvisioningStyle'] = 'Manual'

      # apply code sign properties
      target_obj.build_configuration_list.build_configurations.each do |build_configuration|
        build_settings = build_configuration.build_settings

        build_settings['DEVELOPMENT_TEAM'] = development_team
        build_settings['CODE_SIGN_IDENTITY'] = code_sign_identity
        build_settings['PROVISIONING_PROFILE'] = provisioning_profile_uuid
        build_settings['CODE_SIGN_STYLE'] = 'Manual'
      end
    end

    project.save
  end
end
