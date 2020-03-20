#!/usr/bin/env python3 
import argparse
from re import search
import subprocess
from yaml import safe_load_all

_DEFAULT_CONFIG_ = '/etc/npdisksetup/setupcfg.yml'
_EXIT_SUCCESS_ = 0
_EXIT_BAD_EUID_ = 2
_EXIT_BAD_CFG_DEF_ = 3
_EXIT_BAD_CRYPT_ = 4
_EXIT_BAD_MOUNT_ = 5
_EXIT_UNKNOWN_ = 255

def check_euid(stdout_stderr_text=None, use_os_euid=False, exit_on_fail=True):
    is_non_root = False
    if (use_os_euid):
        is_non_root = True
    elif not stdout_stderr_text is None:
        pattern = 'running as non-root user'
        is_non_root = bool(search(pattern, stdout_stderr_text))

    if is_non_root and exit_on_fail:
        print("Non-root permissions. Try with `sudo\'.")
        exit(_EXIT_BAD_EUID_)
    
    return is_non_root

def get_args():
    parser = argparse.ArgumentParser()
    parser.set_defaults(allow_abbrev=False)

    # postitionals
    parser.add_argument('command', type=str, choices=['start', 'stop'],
        help='The command to perform')
    parser.add_argument('target', type=str, default=['all'], nargs='*',
        help='The target id found in the setupcfg file to process. ' \
            'Default is "all".')

    # optionals
    parser.add_argument('-f', '--file', dest='file', 
        type=argparse.FileType('r'),
        default=_DEFAULT_CONFIG_,
        help='Path to a setupcfg file to use instead of the default.')
    
    return parser.parse_args()

def get_cfg_contents(fstream):
    defs = 0; result = {}
    for doc in safe_load_all(fstream):
        defs += 1
        if not 'id' in doc:
            print('Config target %i missing "%s" element.' % (defs, 'id'))
            exit(_EXIT_BAD_CFG_DEF_)

        result[doc['id']] = doc

    return result

def process_request(cfg, args):
    for target in args['target']:
        if is_meta_target(cfg[target]):
            process_meta_request(cfg, target, args)
        else:
            process_leaf_request(cfg[target], args)
        
def is_meta_target(target_cfg):
    return True if 'targets' in target_cfg else False

def process_meta_request(cfg, target, args):
    # TODO need to handle/store options at the meta target level
    targets = cfg[target]['targets']
    if not isinstance(targets, list):
        print('Element "targets" for %s is not a list.' % target)
        exit(_EXIT_BAD_CFG_DEF_)
    elif len(targets) < 1:
        print('%s defines no targets. Nothing to do.' % target)
        exit(_EXIT_SUCCESS_)

    if any(not t in cfg for t in targets):
        print('One or more targets for %s do not exist.' % target)
        exit(_EXIT_BAD_CFG_DEF_)

    for t in targets:
        process_request(cfg, {'target':[t], 'command':args['command']})

def process_leaf_request(cfg, args):
    funcs = [handle_crypt, handle_mount]
    if 'stop' == args['command']:
        funcs.reverse()
    
    for f in funcs:
        f(cfg, args['command'])

def handle_crypt(cfg, command):
    if not 'crypt' in cfg:
        return
    crypt = cfg['crypt']

    if not 'name' in crypt:
        print('%s defines crypt without name element.' % cfg['id'])
        exit(_EXIT_BAD_CFG_DEF_)
    
    if not can_change_crypt_state(crypt['name'], command):
        return
    
    if not 'device' in crypt:
        if not is_in_crypttab(crypt['name']):
            print('%s crypt name %s not in crypttab and no device specified.' % 
                (cfg['id'], crypt['name']))
            exit(_EXIT_BAD_CRYPT_)

        handle_crypt_cryptdisks(crypt, command)
    else:
        handle_crypt_cryptsetup(crypt, command)

def is_in_crypttab(crypt_name):
    pattern = f'^\s*{crypt_name}\s'
    return any(search(pattern, line) for line in open('/etc/crypttab','r'))

def handle_crypt_cryptdisks(crypt_def, command):
    invoke_subprocess(
        f'cryptdisks_{command}', crypt_def['name'],
        fail_code=_EXIT_BAD_CRYPT_)

def handle_crypt_cryptsetup(crypt_def, command):
    if 'stop' == command:
        invoke_subprocess(
            'cryptsetup', 'close', crypt_def['name'],
            fail_code=_EXIT_BAD_CRYPT_)
    else:
        invoke_subprocess(
            'cryptsetup', 'open', crypt_def['device'], crypt_def['name'],
            fail_code=_EXIT_BAD_CRYPT_)

def can_change_crypt_state(crypt_name, command):
    if 'stop' == command and not can_inactivate_crypt(crypt_name):
        print('crypt: %s is already stopped, skipping.' % crypt_name)
        return False
    elif 'start' == command and not can_activate_crypt(crypt_name):
        print('crypt: %s is already running, skipping.' % crypt_name)
        return False
    return True

def can_activate_crypt(crypt_name):
    return not can_inactivate_crypt(crypt_name)

def can_inactivate_crypt(crypt_name):
    result = invoke_subprocess(
        'cryptsetup', 'status', crypt_name,
        handle_output=False)
    
    check_euid(result.stdout + result.stderr)
    
    return False if f'{crypt_name} is inactive' in result.stdout else True

def handle_mount(cfg, command):
    if 'start' == command and 'options' in cfg and 'nomount' in cfg['options']:
        return
    
    device = try_get_mount_device(cfg)
    mount_dir = try_get_mount_dir(cfg)
    if 'start' == command:
        handle_mount_mount(cfg['id'], device, mount_dir)
    else:
        handle_mount_umount(cfg['id'], device, mount_dir)
    
def try_get_mount_device(cfg):
    if 'mount' in cfg and 'device' in cfg['mount']:
        return cfg['mount']['device']
    elif 'crypt' in cfg:
        return f'/dev/mapper/{cfg["crypt"]["name"]}'
    return None

def try_get_mount_dir(cfg):
    if 'mount' in cfg and 'dir' in cfg['mount']:
        return cfg['mount']['dir']
    return None

def handle_mount_mount(cfg_id, device, mount_dir):
    if device is None:
        print('Cannot mount for %s, no device defined.' % cfg_id)
        exit(_EXIT_BAD_CFG_DEF_)
    
    is_mounted = is_device_mounted(device)
    if is_mounted:
        print('mount: Device %s for %s is already mounted, skipping.' %
            (device, cfg_id))
        return

    if not mount_dir is None:
        invoke_subprocess(
            'mount', '-v', device, mount_dir,
            fail_code=_EXIT_BAD_MOUNT_)
    elif is_device_in_fstab(device):
        invoke_subprocess(
            'mount', '-v', device,
            fail_code=_EXIT_BAD_MOUNT_)
    else:
        print('Device %s for %s not in fstab and no defined mount dir.' %
            (device, cfg_id))
        exit(_EXIT_BAD_CFG_DEF_)

def is_device_mounted(device):
    output = invoke_subprocess('mount', handle_output=False)
    check1 = any(search(f'^{device} on', line)
        for line in output.stdout.split('\n'))
    check2 = any(search(f'on {device} type', line)
        for line in output.stdout.split('\n'))
    result = check1 or check2
    return result

def is_device_in_fstab(device):
    pattern=f'^\s*{device}\s'
    return any(search(pattern, line) for line in open('/etc/fstab', 'r'))

def handle_mount_umount(cfg_id, device, mount_dir):
    target = mount_dir if not mount_dir is None else device

    if not is_device_mounted(target):
        print('umount: %s is not mounted, skipping.' % target)
        return
   
    if not target is None:
        invoke_subprocess('sync',fail_code=_EXIT_BAD_MOUNT_)
        invoke_subprocess(
            'umount', '-v', target,
            fail_code=_EXIT_BAD_MOUNT_)
    else:
        print('No mount dir or device defined for umount of %s.' % cfg_id)
        exit(_EXIT_BAD_MOUNT_)

def invoke_subprocess(*args, **kwargs):
    cargs = list(args)
    if not 'fail_code' in kwargs:
        kwargs['fail_code'] = _EXIT_UNKNOWN_
    if not 'handle_output' in kwargs:
        kwargs['handle_output'] = True

    result = subprocess.run(
        cargs,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        encoding='UTF-8')
    
    if kwargs['handle_output']:
        print_output_stream(result.stdout, result.stderr)
        if result.returncode != 0:
            exit(kwargs['fail_code'])
    
    return result

def print_output_stream(*args):
    for stream in args:
        if stream.strip() != '':
            print(stream)

if __name__ == '__main__':
    check_euid()
    args = vars(get_args())
    cfg = get_cfg_contents(args['file'])
    args['file'].close()

    process_request(cfg, args)
    exit(_EXIT_SUCCESS_)
