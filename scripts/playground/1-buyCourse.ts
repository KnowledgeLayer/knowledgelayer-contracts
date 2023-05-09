import hre, { ethers } from 'hardhat';
import { getDeploymentProperty, ConfigProperty } from '../../.deployment/deploymentManager';

async function main() {
  const network = hre.network.name;
  console.log('Network:', network);

  const [bob] = await ethers.getSigners();

  // Get contract
  const knowledgeLayerCourse = await ethers.getContractAt(
    'KnowledgeLayerCourse',
    getDeploymentProperty(network, ConfigProperty.KnowledgeLayerCourse),
  );

  // Set data
  const courseId = 1;
  const tx = await knowledgeLayerCourse.connect(bob).buyCourse(courseId, {
    value: ethers.utils.parseEther('0.00000001'),
  });
  await tx.wait();

  console.log('Bought course with id: ', courseId);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});