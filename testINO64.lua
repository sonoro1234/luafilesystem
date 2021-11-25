local ffi = require"ffi"
local ffi_str = ffi.string
local lib = ffi.C
local OS = ffi.os

--stat hack to detect INO64 on osx
local isINO64
if OS=='OSX' then
    local f = io.popen('stat -s .', 'r')
    if f then
        local r = f:read("*a")
        f:close()
        if r:match"st_birthtime" then
            isINO64 = true
        else
            isINO64 = false
        end
    end
end

local osxversion
if OS=='OSX' then
	local function version_read()
		local f = io.popen('sw_vers -productVersion')
		if f then
			local r = f:read"*a"
			f:close()
			return r:gsub("\n", "") 
		end
	end
	osxversion = version_read()
end

ffi.cdef( [[
                /* when _DARWIN_FEATURE_64_BIT_INODE is defined */
                typedef struct {
                    uint64_t d_ino;        /* file number of entry */
                    uint64_t d_seekoff;    /* seek offset (optional, used by servers) */
                    uint16_t d_reclen;     /* length of this record */
                    uint16_t d_namlen;     /* length of string in d_name */
                    uint8_t  d_type;       /* file type, see below */
                    char     d_name[1024]; /* name must be no longer than this */
                } dirent64_t;
        typedef struct  __dirstream DIR;
        DIR *opendir(const char *name);
        dirent64_t *readdir(DIR *dirp);
        int closedir(DIR *dirp);
    ]])
	
local readdir_cast = "dirent64_t"
    if OS == 'OSX' then

        local de = lib.opendir('/tmp')
        local e = de and lib.readdir(de) or nil
        -- assume '.' will be the first one (inode or tree order)
        if e and (e.d_type ~= 4 or e.d_namlen ~= 1 or ffi_str(e.d_name) ~= '.') then
            ffi.cdef([[
            /* _DARWIN_FEATURE_64_BIT_INODE is NOT defined here? */
            typedef struct  {
                uint32_t d_ino;
                uint16_t d_reclen;
                uint8_t  d_type;
                uint8_t  d_namlen;
                char d_name[256];
            } dirent32;
        ]])
            readdir_cast = 'dirent32 *'
            e = ffi.cast('dirent32 *', e)
            if not (e and e.d_type == 4 and e.d_namlen == 1 and ffi_str(e.d_name) == '.') then
                readdir_cast = nil
            end
        end
        if de then
            lib.closedir(de)
        end
    end

print(OS, "isINO64 = ", isINO64, "ffi.arch", ffi.arch, "ffi.abi('64bit')", ffi.abi('64bit'), "version", osxversion, "readdir_cast", readdir_cast)