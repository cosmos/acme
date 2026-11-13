package types_test

import (
	"testing"

	"github.com/cosmos/acme/testutil"
	"github.com/cosmos/acme/x/tokenfactory/types"
	"github.com/stretchr/testify/require"
)

func TestValidateGenesis(t *testing.T) {
	testutil.SafeSetAddressPrefixes()
	tests := []struct {
		name      string
		genState  types.GenesisState
		expectErr bool
	}{
		{
			name:      "default genesis",
			genState:  *types.DefaultGenesis(),
			expectErr: false,
		},
		{
			name: "valid genesis with denoms",
			genState: types.GenesisState{
				Params: types.DefaultParams(),
				FactoryDenoms: []types.GenesisDenom{
					{
						Denom: "uacmeusd",
						AuthorityMetadata: types.DenomAuthorityMetadata{
							Admin: "acme1d3cvu588a0t8s4253pz2qsa858svlmlyyvcsm8",
						},
					},
					{
						Denom: "uacmeusd2",
						AuthorityMetadata: types.DenomAuthorityMetadata{
							Admin: "acme10qt9pkv9ecj5nwd4cqmxpztgy4ndl2ccea4hjp",
						},
					},
				},
			},
			expectErr: false,
		},
		{
			name: "invalid denom in genesis",
			genState: types.GenesisState{
				Params: types.DefaultParams(),
				FactoryDenoms: []types.GenesisDenom{
					{
						Denom: "invalid-denom",
						AuthorityMetadata: types.DenomAuthorityMetadata{
							Admin: "acme1creator",
						},
					},
				},
			},
			expectErr: true,
		},
		{
			name: "empty admin in genesis",
			genState: types.GenesisState{
				Params: types.DefaultParams(),
				FactoryDenoms: []types.GenesisDenom{
					{
						Denom: "token1",
						AuthorityMetadata: types.DenomAuthorityMetadata{
							Admin: "",
						},
					},
				},
			},
			expectErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := types.ValidateGenesis(tt.genState)
			if tt.expectErr {
				require.Error(t, err)
				return
			}
			require.NoError(t, err)
		})
	}
}

func TestParamsValidate(t *testing.T) {
	testutil.SafeSetAddressPrefixes()
	require.NoError(t, types.DefaultParams().Validate())
	require.NoError(t, types.Params{}.Validate())
}
